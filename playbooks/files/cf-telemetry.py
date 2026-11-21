#!/usr/bin/env python3
"""
cf-telemetry — лёгкая телеметрия для узлов без Osquery (Alpine / iot-sensor-1).

Отдаёт JSON с теми же полями, что и SQL-запросы Osquery в плейбуках 02 и 05,
поэтому CMDB-дашборд обрабатывает все узлы одинаково.

  cf-telemetry inventory   -> system, os, kernel, packages, users, ports, interfaces, uptime
  cf-telemetry audit       -> fim, deleted_procs, tmp_procs, uid0, ports

Источники: /proc, /etc/passwd, /etc/os-release, apk.
"""
import hashlib
import json
import os
import platform
import socket
import subprocess
import sys

FIM_FILES = ["/etc/passwd", "/etc/shadow", "/etc/ssh/sshd_config", "/etc/sudoers"]
LOGIN_SHELL_EXCLUDE = ("nologin", "/false", "/sync", "/shutdown", "/halt")


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return default


def passwd_entries():
    users = []
    for line in read("/etc/passwd").splitlines():
        parts = line.split(":")
        if len(parts) >= 7:
            users.append({"username": parts[0], "uid": parts[2], "gid": parts[3],
                          "directory": parts[5], "shell": parts[6]})
    return users


def os_release():
    data = {}
    for line in read("/etc/os-release").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            data[k] = v.strip('"')
    return data


def meminfo_bytes():
    for line in read("/proc/meminfo").splitlines():
        if line.startswith("MemTotal:"):
            return str(int(line.split()[1]) * 1024)
    return "0"


def cpu_info():
    brand, cores = "", 0
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name") and not brand:
            brand = line.split(":", 1)[1].strip()
        if line.startswith("processor"):
            cores += 1
    return brand or platform.machine(), str(cores or os.cpu_count() or 1)


def pid_by_inode():
    """inode сокета -> (pid, имя процесса)"""
    result = {}
    for pid in filter(str.isdigit, os.listdir("/proc")):
        fd_dir = f"/proc/{pid}/fd"
        try:
            fds = os.listdir(fd_dir)
        except OSError:
            continue
        name = read(f"/proc/{pid}/comm").strip()
        for fd in fds:
            try:
                target = os.readlink(f"{fd_dir}/{fd}")
            except OSError:
                continue
            if target.startswith("socket:["):
                result[target[8:-1]] = (pid, name)
    return result


def hex_to_addr(hex_addr, v6):
    if not v6:
        return socket.inet_ntop(socket.AF_INET, bytes.fromhex(hex_addr)[::-1])
    raw = bytes.fromhex(hex_addr)
    raw = b"".join(raw[i:i + 4][::-1] for i in range(0, 16, 4))
    return socket.inet_ntop(socket.AF_INET6, raw)


def listening_ports():
    """Аналог osquery listening_ports JOIN processes"""
    owners = pid_by_inode()
    ports, seen = [], set()
    # (файл, протокол как в osquery: 6=tcp, 17=udp, ipv6?)
    for path, proto, v6 in (("/proc/net/tcp", "6", False), ("/proc/net/tcp6", "6", True),
                            ("/proc/net/udp", "17", False), ("/proc/net/udp6", "17", True)):
        lines = read(path).splitlines()[1:]
        for line in lines:
            cols = line.split()
            if len(cols) < 10:
                continue
            local, state, inode = cols[1], cols[3], cols[9]
            if proto == "6" and state != "0A":      # 0A = LISTEN
                continue
            if proto == "17" and state != "07":     # 07 = UDP "unconnected"
                continue
            addr_hex, port_hex = local.split(":")
            port = int(port_hex, 16)
            address = hex_to_addr(addr_hex, v6)
            if port == 0 or address == "127.0.0.11":   # 127.0.0.11 — встроенный DNS Docker
                continue
            pid, name = owners.get(inode, ("", ""))
            key = (port, proto, address)
            if key in seen:
                continue
            seen.add(key)
            ports.append({"port": str(port), "protocol": proto, "address": address,
                          "process": name, "pid": pid})
    return ports


def interfaces():
    out = []
    try:
        res = subprocess.run(["ip", "-o", "-4", "addr", "show"], capture_output=True, text=True)
        for line in res.stdout.splitlines():
            parts = line.split()
            addr = parts[3].split("/")[0]
            if addr.startswith("172.30."):
                out.append({"interface": parts[1], "address": addr})
    except OSError:
        pass
    return out


def package_count():
    try:
        res = subprocess.run(["apk", "info"], capture_output=True, text=True)
        return str(len([l for l in res.stdout.splitlines() if l.strip()]))
    except OSError:
        return "0"


def inventory():
    osr = os_release()
    brand, cores = cpu_info()
    users = [u for u in passwd_entries()
             if not any(x in u["shell"] for x in LOGIN_SHELL_EXCLUDE)]
    return {
        "system": [{"hostname": socket.gethostname(), "cpu_brand": brand,
                    "cpu_logical_cores": cores, "physical_memory": meminfo_bytes()}],
        "os": [{"name": osr.get("NAME", "Linux"), "version": osr.get("VERSION_ID", ""),
                "platform": osr.get("ID", "")}],
        "kernel": [{"version": platform.release()}],
        "packages": [{"count": package_count(), "manager": "apk"}],
        "users": users,
        "ports": listening_ports(),
        "interfaces": interfaces(),
        "uptime": [{"total_seconds": read("/proc/uptime", "0 0").split()[0].split(".")[0]}],
        "source": "cf-telemetry (no osquery on Alpine)",
    }


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def deleted_processes():
    """Аналог: SELECT pid, name, path, cmdline FROM processes WHERE on_disk = 0"""
    procs = []
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            exe = os.readlink(f"/proc/{pid}/exe")
        except OSError:
            continue
        if exe.endswith(" (deleted)"):
            cmd = read(f"/proc/{pid}/cmdline").replace("\0", " ").strip()
            procs.append({"pid": pid, "name": read(f"/proc/{pid}/comm").strip(),
                          "path": exe[:-10], "cmdline": cmd})
    return procs


TMP_PREFIXES = ("/tmp/", "/var/tmp/", "/dev/shm/")


def tmp_processes():
    """Аналог: процессы, запущенные из /tmp, /var/tmp, /dev/shm (бинарник ещё на диске)"""
    procs = []
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            exe = os.readlink(f"/proc/{pid}/exe")
        except OSError:
            continue
        if exe.endswith(" (deleted)"):
            continue
        args = read(f"/proc/{pid}/cmdline").split("\0")
        if exe.startswith(TMP_PREFIXES) or any(a.startswith(TMP_PREFIXES) for a in args):
            procs.append({"pid": pid, "name": read(f"/proc/{pid}/comm").strip(), "path": exe,
                          "cmdline": " ".join(a for a in args if a)})
    return procs


def audit():
    fim = []
    for path in FIM_FILES:
        if os.path.exists(path):
            fim.append({"path": path, "sha256": sha256(path)})
    uid0 = [u for u in passwd_entries() if u["uid"] == "0" and u["username"] != "root"]
    return {"fim": fim, "deleted_procs": deleted_processes(), "tmp_procs": tmp_processes(), "uid0": uid0,
            "ports": listening_ports()}


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "inventory"
    data = audit() if mode == "audit" else inventory()
    print(json.dumps(data))

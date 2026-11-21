#!/bin/bash
# CyberFleet 2026 — полный запуск с нуля (недели 1–3). Запускать на хосте с Docker.
#   bash setup.sh
set -e
cd "$(dirname "$0")"

run() { echo; echo "==> $*"; docker exec hq-controller bash -c "cd /ansible && $*"; }

echo "==> [1/8] Build and start 8 containers"
docker compose up -d --build

echo "==> waiting for sshd..."; sleep 5

echo "==> [2/8] Zero Trust check: IoT must NOT reach ws-fin-01"
if docker exec iot-sensor-1 ping -c 2 -W 2 ws-fin-01 >/dev/null 2>&1; then
  echo "FAIL: iot-sensor-1 can reach ws-fin-01"; exit 1
else
  echo "OK: iot-sensor-1 -> ws-fin-01 blocked"
fi
docker exec hq-controller ping -c 1 -W 2 ws-fin-01 >/dev/null && echo "OK: hq-controller -> ws-fin-01"
docker exec hq-controller ping -c 1 -W 2 iot-cam-1 >/dev/null && echo "OK: hq-controller -> iot-cam-1"

run "bash scripts/distribute_keys.sh"                       # [3/8] SSH keys
run "ansible all -m ping"                                    # [3/8] 100% green
run "ansible-playbook playbooks/01_deploy_agents.yml"        # [4/8] Osquery + telemetry
run "ansible-playbook playbooks/03_profiles.yml"             # [5/8] profiles
run "ansible-playbook playbooks/04_hardening.yml"            # [6/8] hardening + self-healing cron
run "ansible-playbook playbooks/02_generate_cmdb.yml"        # [7/8] CMDB
run "ansible-playbook playbooks/05_security_audit.yml"       # [7/8] FIM baseline + audit
run "ansible-playbook playbooks/06_fleet_backup.yml"         # [8/8] encrypted backup

echo
echo "Done. CMDB dashboard: http://localhost:8080"

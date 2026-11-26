# CyberFleet 2026 — cyberfleet-projekt

KS 7.0 lõpuprojekt: NordicTech OÜ klientseadmete pargi ehitamine, tsentraalne haldus ja küberkaitse
(**Docker Compose + Ansible + Osquery**).

- **8 konteinerit, 4 OS-i** (Ubuntu 24.04, Debian 12, Rocky Linux 9, Alpine 3.20) **3 võrgus** (Zero Trust)
- **CMDB & Turvaseire armatuurlaud** → <http://localhost:8080>
- Self-healing (cron), Osquery HIDS/FIM, AES-256 varundus, automaatne intsidendi taaste (**35 s**)

| Dokument | Sisu |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | võrguskeem, IP-plaan, rollid, turvameetmed, disainiotsused |
| [INCIDENT_REPORT.md](INCIDENT_REPORT.md) | Chaos Monkey rünnaku analüüs ja taaste |
| [docs/E-ITS.md](docs/E-ITS.md) | E-ITS 2026 vastendus: varad ↔ moodulid ↔ meetmed |
| [docs/evidence/](docs/evidence) | testide väljundid (ping, ansible ping, audit, taaste) |

## Nõuded

- Docker Engine / Docker Desktop + Docker Compose v2
- ~3 GB vaba kettaruumi, internet (image'id ja paketid)
- Töötab x86_64 ja ARM64 (Apple Silicon) peal — Osquery repo toetab mõlemat

## Kiirjuhend (Quickstart)

```bash
git clone https://github.com/timofei140608-sketch/cyberfleet-projekt.git
cd cyberfleet-projekt
bash setup.sh
```

`setup.sh` teeb kõik järjest (u 3–5 min): ehitab ja käivitab 8 konteinerit → kontrollib
segmenteerimist → jagab SSH võtmed → `ansible all -m ping` → playbookid 01, 03, 04, 02, 05, 06.
Seejärel ava **<http://localhost:8080>**.

### Samm-sammult (käsitsi)

```bash
docker compose up -d --build                                     # 8 konteinerit, 3 võrku
docker exec iot-sensor-1 ping -c 2 ws-fin-01                     # PEAB ebaõnnestuma (bad address)
docker exec hq-controller ping -c 2 ws-fin-01                    # töötab
docker exec hq-controller bash scripts/distribute_keys.sh        # Ed25519 võti → 7 seadet
docker exec hq-controller ansible all -m ping                    # 7 × SUCCESS
```

Kõik `ansible-playbook` käsud käivitatakse **hq-controlleris** (repo on seal `/ansible`):

```bash
docker exec -it hq-controller bash          # sisse; edasi:
ansible-playbook playbooks/01_deploy_agents.yml      # 2. nädal: Osquery + Alpine telemeetria
ansible-playbook playbooks/03_profiles.yml           # 2. nädal: arendaja / raamatupidaja / kiosk
ansible-playbook playbooks/04_hardening.yml          # 3. nädal: karastamine + cron self-healing
ansible-playbook playbooks/02_generate_cmdb.yml      # 2. nädal: CMDB → http://localhost:8080
ansible-playbook playbooks/05_security_audit.yml     # 3. nädal: HIDS/FIM (1. käivitus = baasjoon)
ansible-playbook playbooks/06_fleet_backup.yml       # 3. nädal: AES-256 varundus backup-vault'i
```

> ⚠️ Järjekord: **võtmed enne 04-t** — 04 keelab parooliga SSH sisselogimise.

### 4. nädal — Chaos Monkey ja taaste

```bash
bash scripts/chaos_attack.sh                                                     # rünnak (hostis)
docker exec hq-controller ansible-playbook playbooks/05_security_audit.yml       # avastamine → punane
docker exec hq-controller ansible-playbook playbooks/07_incident_response.yml    # taaste → roheline
```

## Playbookid

| Fail | Nädal | Mida teeb |
|---|---|---|
| `01_deploy_agents.yml` | 2 | Osquery (APT/DNF ametlik repo) Ubuntu/Debian/Rocky + hq-controller; Alpine'ile `cf-telemetry` (apk) |
| `02_generate_cmdb.yml` | 2 | Osquery SQL: hostname, IP, tsoon, OS, tuum, CPU, RAM, pakettide arv, login-kasutajad, pordid → `/var/www/html/index.html` |
| `03_profiles.yml` | 2 | arendaja (aliased, .gitconfig, sudo, git/vim/htop), raamatupidaja (umask 0077, ilma sudota), kiosk (rbash) |
| `04_hardening.yml` | 3 | SSH ainult võtmega, root keelatud, bännerid, telnet/netcat/kompilaatorid maha, triivi parandus, cron |
| `05_security_audit.yml` | 3–4 | FIM SHA-256 baasjoon, `on_disk = 0`, /tmp protsessid, UID=0, lubamata pordid → punased häired |
| `06_fleet_backup.yml` | 3 | ws-fin-01 dokumendid, ws-dev-01 kood, srv-app-01 konfig, iot-sensor-1 logid → AES-256 + SHA-256 → backup-vault |
| `07_incident_response.yml` | 4 | tagaukse kontod maha, pahavara karantiin + kill, pordid kinni, failid varukoopiast tagasi, 04 + 05 uuesti |

Automaatika (hq-controlleri cron, paigaldab 04): **iga 10 min** 04 (self-healing), **iga 5 min** 02 + 05
(armatuurlaud), **öösel 02:15** 06 (varundus). Logid: `/var/log/cyberfleet/`.

## Hoidla struktuur

```
cyberfleet-projekt/
├── README.md  ARCHITECTURE.md  INCIDENT_REPORT.md
├── docker-compose.yml            # 8 konteinerit, 3 võrku, staatilised IP-d
├── hosts.ini  ansible.cfg        # Ansible inventar ja seadistus
├── setup.sh                      # kogu paigaldus ühe käsuga
├── group_vars/all.yml            # ühised muutujad (tsoonid, lubatud pordid, varundus, FIM failid)
├── host_vars/                    # srv-app-01 (port 8000), localhost (= hq-controller)
├── Dockerfiles/                  # hq-controller, ubuntu, debian, debian-slim, rocky, alpine
├── playbooks/
│   ├── 01_deploy_agents.yml … 07_incident_response.yml
│   ├── templates/cmdb.html.j2    # armatuurlaud
│   ├── tasks/render_dashboard.yml
│   └── files/cf-telemetry.py     # Alpine telemeetria (Osquery asendus)
├── profiles/                     # kuldsed profiilid: dev/, fin/, kiosk/
├── scripts/
│   ├── distribute_keys.sh        # Ed25519 võtme loomine ja levitamine
│   └── chaos_attack.sh           # ülesande ründeskript (proovimiseks)
└── docs/                         # E-ITS.md, evidence/, img/
```

## Kasutajad (õppelabor)

| Kasutaja | Kus | Õigused | Märkus |
|---|---|---|---|
| `ansible` | kõik 7 | sudo NOPASSWD | ajutine parool `Passw0rd` ainult võtmete jagamiseks; pärast 04 ainult võti |
| `arendaja` | ws-dev-01 | sudo (parooliga) | `Arendaja2026!` |
| `raamatupidaja` | ws-fin-01 | ilma sudota, umask 0077 | `Raamat2026!` |
| `kiosk` | kiosk-lobby | rbash, ilma sudota | `Kiosk2026!` |

Gitis on ainult paroolide SHA-512 räsid. SSH-võti ja varunduse krüptovõti tekivad hq-controlleri
Docker-köidetesse (`hq_ssh`, `hq_data`) ja **ei satu kunagi Giti**.

## Tõrkeotsing

| Sümptom | Põhjus / lahendus |
|---|---|
| `distribute_keys.sh`: FAIL | konteiner pole veel valmis → oota 5 s ja käivita uuesti (skript on idempotentne) |
| FAIL pärast 04 käivitamist | uues konteineris on parool lubatud, vanas mitte → `docker compose down -v && bash setup.sh` |
| `ansible.cfg` ignoreeritakse (Windows) | `ANSIBLE_CONFIG=/ansible/ansible.cfg` on compose'is juba seatud |
| `bad interpreter: /bin/bash^M` | Windowsi reavahetused → `.gitattributes` hoiab LF; `git rm --cached -r . && git reset --hard` |
| Armatuurlaud tühi | käivita 02 ja 05 (või oota 5 min — cron) |
| FIM häire pärast legitiimset muudatust | `ansible-playbook playbooks/05_security_audit.yml -e fim_rebaseline=true` |
| Port 8080 hõivatud | muuda `docker-compose.yml`: `"8081:80"` |

## Puhastus

```bash
docker compose down        # peata
docker compose down -v     # peata + kustuta köited (võtmed, varukoopiad, baasjoon)
```

## Meeskond

| Liige | Roll |
|---|---|
| Herman | Meeskonna juht, integratsioon, dokumentatsioon |
| RedFildous | Docker Compose ja võrgud |
| Munezyku | Dockerfile'id (image'id) |
| timofei140608-sketch | Ansible ja SSH võtmed |

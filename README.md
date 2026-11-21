# cyberfleet-projekt

CyberFleet 2026: Docker + Ansible + Osquery.
Виртуальный парк NordicTech OÜ: 8 устройств, 4 ОС, 3 сетевые зоны.

## Структура

```
cyberfleet-projekt/
├── README.md            # быстрый старт
├── ARCHITECTURE.md      # схема сети, IP-план, роли, меры защиты
├── INCIDENT_REPORT.md   # анализ атаки и восстановления
├── docker-compose.yml
├── hosts.ini
├── ansible.cfg
├── Dockerfiles/         # образы по ОС
├── scripts/             # вспомогательные скрипты (раздача ключей и т.п.)
├── playbooks/           # 01 ... 07
└── profiles/            # шаблоны профилей dev, fin, kiosk
```

## Договорённости команды (менять нельзя — их использует chaos_attack.sh)

### Имена контейнеров
`hq-controller`, `backup-vault`, `ws-dev-01`, `ws-fin-01`, `srv-app-01`, `kiosk-lobby`, `iot-sensor-1`, `iot-cam-1`

### IP-план

| Сеть | Подсеть | Контейнер | IP |
|---|---|---|---|
| mgmt_net | 172.30.10.0/24 | hq-controller | 172.30.10.10 |
| | | backup-vault | 172.30.10.20 |
| corp_net | 172.30.20.0/24 | hq-controller | 172.30.20.10 |
| | | ws-dev-01 | 172.30.20.11 |
| | | ws-fin-01 | 172.30.20.12 |
| | | srv-app-01 | 172.30.20.13 |
| dmz_iot | 172.30.30.0/24 | hq-controller | 172.30.30.10 |
| | | kiosk-lobby | 172.30.30.11 |
| | | iot-sensor-1 | 172.30.30.12 |
| | | iot-cam-1 | 172.30.30.13 |

### ОС узлов

| ОС | Контейнеры |
|---|---|
| Ubuntu 24.04 | hq-controller, ws-dev-01, ws-fin-01 |
| Debian 12 | backup-vault, kiosk-lobby |
| Rocky Linux 9 | srv-app-01 |
| Alpine | iot-sensor-1 |
| Debian 12 Slim | iot-cam-1 |

### Пользователи
- `ansible` на всех узлах: sudo без пароля, временный пароль `Passw0rd`
  (нужен только для первой раздачи SSH-ключа; на неделе 3 вход по паролю отключается).
- Бухгалтер на ws-fin-01: `raamatupidaja` (путь `/home/raamatupidaja/...` использует скрипт атаки).

## Правила работы с Git
- В `main` напрямую не пушим — только через Pull Request.
- Одна задача = одна ветка (`net-compose`, `dockerfiles`, `ansible-keys`, ...).
- В конце недели — тег `milestone-N`.

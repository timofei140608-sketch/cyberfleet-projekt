# Шпаргалка к защите (для команды, по-русски)

## Порядок демонстрации (≈10 минут)

1. `docker compose ps`: 8 контейнеров, 4 ОС.
2. **Сегментация:** `docker exec iot-sensor-1 ping -c 2 ws-fin-01` → `bad address` (DMZ не видит бухгалтерию).
   `docker exec hq-controller ping -c 2 ws-fin-01` → работает.
3. `docker exec hq-controller ansible all -m ping` → 7 × SUCCESS (по ключу Ed25519, без пароля).
4. Открыть **http://localhost:8080**: CMDB (ОС, ядро, CPU, RAM, пакеты, пользователи, порты), всё зелёное.
5. **Профили:** `docker exec kiosk-lobby su - kiosk -c 'cd /etc'` → `restricted`.
6. **Атака:** `bash scripts/chaos_attack.sh`.
7. `docker exec hq-controller ansible-playbook playbooks/05_security_audit.yml` → обновить страницу: **красные тревоги**
   (shadow_admin, xmr_miner, порт 4444).
8. `docker exec hq-controller ansible-playbook playbooks/07_incident_response.yml` (~30 с) → страница **зелёная**,
   внизу отчёт о реагировании. `docker exec ws-fin-01 ls -l /home/raamatupidaja/Raamatupidamine_2026` → файлы на месте.

## Частые вопросы учителя и ответы

| Вопрос | Ответ |
|---|---|
| Почему IoT не видит ws-fin-01? | Это разные Docker-сети (как разные VLAN). Только hq-controller подключён ко всем трём. Docker DNS даёт имена только внутри общей сети, поэтому даже имя не резолвится. |
| Почему на Alpine нет Osquery? | Официально Osquery не поддерживает Alpine (musl). Там стоит наш Python-скрипт `cf-telemetry`, он отдаёт те же поля из /proc и /etc/passwd. |
| Как работает self-healing? | Cron на hq-controller каждые 10 минут запускает 04_hardening.yml. Ansible идемпотентен: если кто-то включил пароли в SSH или сломал киоск, он вернёт правильное состояние. Мы это проверяли. |
| Как вы нашли майнера? | `SELECT … FROM processes WHERE on_disk = 0`: бинарник удалён с диска, а процесс жив. Плюс второе правило: процессы, запущенные из /tmp, /var/tmp, /dev/shm. |
| Зачем второе правило? | В Rocky 9 по умолчанию `coreutils-single`: там `/bin/sleep` — обёртка над `/usr/bin/coreutils`, и `on_disk = 0` майнер не видит. Мы это нашли на репетиции и поставили полный coreutils + добавили правило. |
| Как нашли shadow_admin? | Двумя способами: `users WHERE uid = 0 AND username != 'root'` и FIM: SHA-256 `/etc/passwd` не совпал с эталоном. |
| Где ключ шифрования бэкапов? | Только на hq-controller (`/var/lib/cyberfleet/secrets/backup.key`, права 600). На backup-vault лежит только шифротекст, поэтому взлом vault не раскрывает данные. |
| Какое шифрование? | AES-256-CBC через OpenSSL, ключ выводится через PBKDF2 (200 000 итераций, соль), плюс SHA-256 контрольная сумма, которая проверяется на vault и перед восстановлением. |
| Почему бэкап идёт через hq-controller? | Клиенты по Zero Trust не видят backup-vault (он только в mgmt_net). Контроллер забирает архив, шифрует и отправляет. |
| Зачем python3 на киоске, вы же удаляете лишнее? | Без python3 не работает Ansible (и скрипт атаки учителя). Удаляем telnet, netcat, gcc, make и BusyBox-ссылки `nc`/`telnet`. |
| Что такое rbash? | Restricted bash: нельзя `cd`, нельзя менять PATH, нельзя запускать команды с `/` в имени. PATH указывает только на `/home/kiosk/bin` с 5 разрешёнными командами, файлы профиля принадлежат root. |
| Что такое E-ITS и при чём тут проект? | Эстонский стандарт информационной безопасности (eits.ria.ee). В `docs/E-ITS.md` мы сопоставили каждое устройство с модулями каталога 2026 (SYS.2.3 Linux-рабочая станция, SYS.4.1 IoT, OPS.1.3 бэкап, DER.1 обнаружение и т.д.) и показали, какие меры как реализованы. |
| В задании указаны CON.8 и OPS.1.1.4 — где они? | Это коды старой версии E-ITS. В версии 2026 те же темы: DEV.1 (разработка ПО) и OPS.1.9 (защита от вредоносных программ). |

## Две ошибки, которые мы нашли в скрипте атаки (это плюс на защите)

1. **Rocky + coreutils-single**: майнер не выглядит как «удалённый бинарник» (см. выше).
2. **Инцидент 4**: `docker exec ws-fin-01 rm -rf …/*` запускается без оболочки, поэтому `*` не раскрывается и
   **ничего не удаляется**. В нашей копии `scripts/chaos_attack.sh` удаление идёт через `sh -c`. Наш 07
   работает в обоих случаях.

## Если что-то пошло не так на защите

```bash
docker compose down -v && bash setup.sh          # всё с нуля, ~3–5 минут
```

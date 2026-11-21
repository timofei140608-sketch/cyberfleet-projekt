#!/bin/bash
# Запускать ВНУТРИ hq-controller:
#   docker exec -it hq-controller bash /ansible/scripts/distribute_keys.sh
#
# 1) генерирует SSH-ключ Ed25519 (если его ещё нет);
# 2) раздаёт публичный ключ пользователю ansible на 7 узлов (по паролю, через sshpass);
# 3) проверяет вход по ключу без пароля.
# Скрипт можно запускать повторно: ключ не перезаписывается, дубликаты не добавляются.
#
# Требуется на hq-controller: openssh-client, sshpass.

set -u

PASS="${ANSIBLE_PASS:-Passw0rd}"   # временный пароль пользователя ansible (из Dockerfile-ов)
USER_NAME="${ANSIBLE_USER:-ansible}"
KEY="${KEY:-$HOME/.ssh/id_ed25519}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)

# имя:IP — совпадает с hosts.ini и IP-планом
HOSTS=(
  "backup-vault:172.30.10.20"
  "ws-dev-01:172.30.20.11"
  "ws-fin-01:172.30.20.12"
  "srv-app-01:172.30.20.13"
  "kiosk-lobby:172.30.30.11"
  "iot-sensor-1:172.30.30.12"
  "iot-cam-1:172.30.30.13"
)

for bin in ssh-keygen ssh-copy-id sshpass; do
  command -v "$bin" >/dev/null || { echo "[ERR] нет команды $bin — добавьте пакет в Dockerfile hq-controller"; exit 1; }
done

mkdir -p "$(dirname "$KEY")" && chmod 700 "$(dirname "$KEY")"

if [ ! -f "$KEY" ]; then
  ssh-keygen -q -t ed25519 -N "" -f "$KEY" -C "ansible@hq-controller"
  echo "[+] Ключ создан: $KEY"
else
  echo "[=] Ключ уже есть: $KEY"
fi

ok=0; fail=0
for entry in "${HOSTS[@]}"; do
  name="${entry%%:*}"; ip="${entry##*:}"

  # уже пускает по ключу? — ничего не делаем
  if ssh "${SSH_OPTS[@]}" -o BatchMode=yes -i "$KEY" "$USER_NAME@$ip" true 2>/dev/null; then
    printf "[OK]   %-13s %s (ключ уже установлен)\n" "$name" "$ip"; ok=$((ok+1)); continue
  fi

  if sshpass -p "$PASS" ssh-copy-id -f -i "$KEY.pub" "${SSH_OPTS[@]}" "$USER_NAME@$ip" >/dev/null 2>&1 \
     && ssh "${SSH_OPTS[@]}" -o BatchMode=yes -i "$KEY" "$USER_NAME@$ip" true 2>/dev/null; then
    printf "[OK]   %-13s %s\n" "$name" "$ip"; ok=$((ok+1))
  else
    printf "[FAIL] %-13s %s\n" "$name" "$ip"; fail=$((fail+1))
  fi
done

echo "Итого: $ok OK, $fail FAIL"
[ "$fail" -eq 0 ]

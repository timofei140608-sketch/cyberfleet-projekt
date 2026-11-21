#!/bin/sh
# Симулятор IP-камеры: раз в минуту пишет "кадр" в лог, затем sshd на переднем плане
(
  while true; do
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) cam=iot-cam-1 frame=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ') motion=$(( $(od -An -N1 -tu1 /dev/urandom) % 2 ))" >> /var/log/camera.log
    sleep 60
  done
) &
exec /usr/sbin/sshd -D

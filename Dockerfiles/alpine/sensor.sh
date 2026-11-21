#!/bin/sh
# Датчик: каждую минуту пишет температуру в /var/log/sensor.log, затем sshd на переднем плане
(
  while true; do
    t=$(awk -v s="$(od -An -N2 -tu2 /dev/urandom)" 'BEGIN{printf "%.1f", 18 + (s % 120) / 10}')
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) sensor=iot-sensor-1 temp_c=$t" >> /var/log/sensor.log
    sleep 60
  done
) &
exec /usr/sbin/sshd -D

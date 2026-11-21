#!/bin/sh
# Внутренний веб (порт 8000) + sshd на переднем плане
cd /opt/nordicapp && python3 -m http.server 8000 >/var/log/nordicapp.log 2>&1 &
exec /usr/sbin/sshd -D

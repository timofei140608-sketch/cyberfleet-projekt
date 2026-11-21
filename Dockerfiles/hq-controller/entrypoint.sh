#!/bin/bash
# В контейнере нет systemd — запускаем сервисы вручную.
mkdir -p /root/.ssh /var/lib/cyberfleet /var/log/cyberfleet
chmod 700 /root/.ssh /var/lib/cyberfleet
# Пока CMDB ещё не сгенерирован — заглушка
[ -s /var/www/html/index.html ] || echo '<h1>CyberFleet CMDB</h1><p>Run playbooks/02_generate_cmdb.yml</p>' > /var/www/html/index.html
service cron start  >/dev/null 2>&1 || cron
service nginx start >/dev/null 2>&1 || nginx
echo "hq-controller ready"
exec tail -f /dev/null

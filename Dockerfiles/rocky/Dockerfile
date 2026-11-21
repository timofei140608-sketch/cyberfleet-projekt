# Rocky Linux 9 — srv-app-01 (внутренний веб и бизнес-приложение, dnf/rpm)
FROM rockylinux:9

# Полный coreutils вместо coreutils-single: в -single /bin/sleep — это скрипт-обёртка
# над /usr/bin/coreutils, и процесс-копия не выглядит как "удалённый бинарник".
RUN dnf install -y --allowerasing coreutils \
    && dnf install -y openssh-server openssh-clients python3 sudo \
        iputils iproute procps-ng tar gzip ca-certificates \
    && dnf clean all

# В Docker нет systemd: host-ключи генерируем сами
RUN useradd -m ansible \
    && echo 'ansible:Passw0rd' | chpasswd \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 440 /etc/sudoers.d/ansible \
    && ssh-keygen -A \
    && rm -f /run/nologin

# Конфигурация «бизнес-приложения» (её бэкапит 06_fleet_backup.yml)
COPY app/ /opt/nordicapp/
COPY app.conf /etc/nordicapp/app.conf
COPY start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh

EXPOSE 22 8000
CMD ["/usr/local/bin/start.sh"]

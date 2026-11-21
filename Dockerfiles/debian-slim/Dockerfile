# Debian 12 Slim — iot-cam-1 (симулятор IP-камеры)
# ВНИМАНИЕ: конфигурация НАМЕРЕННО слабая (по заданию):
#   - вход root по паролю (root:root) разрешён
#   - стоят telnet и netcat
# Всё это исправляет 04_hardening.yml.
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server python3 sudo ca-certificates \
        iputils-ping iproute2 procps tar gzip \
        telnet netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ansible \
    && echo 'ansible:Passw0rd' | chpasswd \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 440 /etc/sudoers.d/ansible \
    && mkdir -p /run/sshd \
    && echo 'root:root' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

COPY camera.sh /usr/local/bin/camera.sh
RUN chmod 755 /usr/local/bin/camera.sh

EXPOSE 22
CMD ["/usr/local/bin/camera.sh"]

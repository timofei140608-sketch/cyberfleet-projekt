# hq-controller — Ubuntu 24.04: центр управления
# Ansible + Osquery (ставится плейбуком 01) + Nginx (CMDB :8080) + cron (self-healing)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# listen [::]:80 удаляем: если в Docker выключен IPv6, nginx иначе не стартует
RUN apt-get update && apt-get install -y --no-install-recommends \
        ansible openssh-client sshpass python3 python3-apt sudo \
        nginx cron curl ca-certificates gnupg openssl \
        iputils-ping iproute2 procps util-linux tar gzip \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/listen \[::\]:80/d' /etc/nginx/sites-available/default

RUN useradd -m -s /bin/bash ansible \
    && echo 'ansible:Passw0rd' | chpasswd \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 440 /etc/sudoers.d/ansible \
    && mkdir -p /var/lib/cyberfleet /var/log/cyberfleet

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /ansible
EXPOSE 80
CMD ["/entrypoint.sh"]

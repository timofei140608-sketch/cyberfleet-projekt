# Alpine — iot-sensor-1 (заводской датчик температуры)
FROM alpine:3.20

# python3 обязателен: без него Ansible не работает
RUN apk add --no-cache openssh python3 sudo bash tar iproute2 procps

# chpasswd снимает блокировку учётки (иначе sshd не пустит даже по ключу)
RUN adduser -D -s /bin/bash ansible \
    && echo 'ansible:Passw0rd' | chpasswd \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 440 /etc/sudoers.d/ansible \
    && ssh-keygen -A \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

COPY sensor.sh /usr/local/bin/sensor.sh
RUN chmod 755 /usr/local/bin/sensor.sh

EXPOSE 22
CMD ["/usr/local/bin/sensor.sh"]

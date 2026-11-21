#!/bin/bash
# Chaos Monkey — из задания KS 7.0 (раздел 4. NÄDAL), для репетиции защиты.
# Единственное отличие — Intsident 4 (см. комментарий там).
# Запускать на ХОСТЕ (где docker), не внутри контейнера:  bash scripts/chaos_attack.sh
echo "[!] Käivitub Chaos Monkey küberrünnak seadmepargile..."

# Intsident 1: IoT kaamerasse (iot-cam-1) lisatakse salajane root-õigustega tagaukse konto
docker exec iot-cam-1 sh -c "echo 'shadow_admin:x:0:0:root:/root:/bin/bash' >> /etc/passwd"

# Intsident 2: Rakendusserveris (srv-app-01) käivitatakse mälus peidetud krüptokaevur (kustutatud binaariga)
docker exec -d srv-app-01 sh -c "cp /bin/sleep /tmp/xmr_miner && /tmp/xmr_miner 7200 & sleep 1 && rm -f /tmp/xmr_miner"

# Intsident 3: Kioskis (kiosk-lobby) rikutakse SSH konfiguratsioon ja avatakse kahtlane tagaukse port 4444
docker exec -d kiosk-lobby sh -c "python3 -m http.server 4444 >/dev/null 2>&1 &"

# Intsident 4: Raamatupidaja arvutit (ws-fin-01) tabab 'lunavara' – kõik finantsfailid kustutatakse!
# Оригинал из задания:
#   docker exec ws-fin-01 rm -rf /home/raamatupidaja/Raamatupidamine_2026/*
# не удаляет ничего: docker exec запускает rm без оболочки, '*' не раскрывается.
# Для честной репетиции удаляем через sh -c (так файлы реально исчезают):
docker exec ws-fin-01 sh -c 'rm -rf /home/raamatupidaja/Raamatupidamine_2026/*'

echo "[+] Rünnak lõppenud! Administraatoril on aega 10 minutit intsidentide tuvastamiseks ja taastamiseks!"

# INCIDENT REPORT — „Chaos Monkey“ rünnakusimulatsioon

| | |
|---|---|
| **Organisatsioon** | NordicTech OÜ (CyberFleet 2026) |
| **Õppuse tüüp** | Punane vs. sinine tiim (E-ITS DER.3 turvaõppus) |
| **Ründeskript** | `scripts/chaos_attack.sh` (ülesande KS 7.0 skript, vt p 6) |
| **Proovikord** | 21.11.2026, 17:07:58 UTC |
| **Tulemus** | **4/4 intsidenti avastatud ja likvideeritud, rünnakust täieliku taasteni 35 s** (nõue: 5 min) |
| **Tõendid** | `docs/evidence/week4_05_audit_under_attack.txt`, `docs/evidence/week4_07_incident_response.txt`, `docs/img/*.png` |

> Kaitsmisel korratakse sama protsessi; selle raporti ajad on proovikorra tegelikud mõõtmised.

## 1. Kokkuvõte

Ründeskript tekitas seadmepargis neli intsidenti. Osquery HIDS (`05_security_audit.yml`)
tuvastas kolm „nähtavat“ intsidenti 10 sekundiga ja kuvas need punaselt CMDB armatuurlaual.
Taasteplaan `07_incident_response.yml` eemaldas tagaukse konto, tappis krüptokaevuri (näidis
karantiini), sulges pordi 4444 ja taastas raamatupidaja 3 faili AES-256 krüpteeritud varukoopiast.
Pärast seda rakendati turvapoliitika uuesti ja korduvaudit oli roheline.

## 2. Ajajoon (UTC)

| Aeg | T+ | Sündmus |
|---|---|---|
| 17:06:34 | — | Viimane öine/plaaniline varukoopia `cf_ws-fin-01_20261121T170634Z.tar.gz.enc` backup-vault'is |
| **17:07:58** | 0 s | `chaos_attack.sh` käivitatakse |
| 17:08:00 | 2 s | Kõik 4 intsidenti aktiivsed |
| 17:08:00 | 2 s | `ansible-playbook playbooks/05_security_audit.yml` |
| **17:08:09** | **11 s** | Armatuurlaud: **5 punast häiret** 3 seadmes (vt `docs/img/cmdb_under_attack.png`) |
| 17:08:12 | 14 s | `ansible-playbook playbooks/07_incident_response.yml` |
| 17:08:15 | 17 s | Isoleerimine + likvideerimine + failide taaste lõpetatud (3 s) |
| 17:08:15–17:08:33 | | Turvapoliitika (04) uuesti rakendatud kõigis 7 seadmes |
| **17:08:34** | **35 s** | Korduvaudit: **🟢 0 häiret** (vt `docs/img/cmdb_after_recovery.png`) |

## 3. Intsidendid, avastamine ja reageerimine

### Intsident 1 — tagaukse konto `iot-cam-1`
- **Rünne:** `echo 'shadow_admin:x:0:0:root:/root:/bin/bash' >> /etc/passwd`
- **Avastamine (2 sõltumatut kontrolli):**
  - `SELECT username, uid FROM users WHERE uid = 0 AND username != 'root'` → `BACKDOOR shadow_admin`
  - FIM: `SELECT path, sha256 FROM hash WHERE path = '/etc/passwd'` → räsi ≠ baasjoon (`4786afe3… → 95ceb9c1…`)
- **Reageerimine:** UID=0 kontod (v.a root) eemaldatakse failidest `/etc/passwd`, `/etc/shadow`,
  `/etc/group`, `/etc/gshadow`. Pärast eemaldamist on `/etc/passwd` räsi taas **täpselt baasjoonega võrdne**.

### Intsident 2 — mälus peidetud krüptokaevur `srv-app-01`
- **Rünne:** `/bin/sleep` kopeeritakse `/tmp/xmr_miner`, käivitatakse ja binaar kustutatakse.
- **Avastamine:**
  - `SELECT pid, name, path FROM processes WHERE on_disk = 0` → `MALWARE xmr_miner pid 3151 … DELETED binary /tmp/xmr_miner`
  - lisareegel: protsessid, mis käivitati `/tmp`, `/var/tmp`, `/dev/shm` alt → `SUSPICIOUS sh -c cp /bin/sleep /tmp/xmr_miner …` (dropper)
- **Reageerimine:** iga sellise protsessi `/proc/<pid>/exe` kopeeritakse karantiini
  `/root/quarantine/<aeg>_<nimi>_<pid>.bin` (õigused 000, SHA-256 logitakse — asitõend, E-ITS DER.2.2),
  seejärel `kill -9`. SSH-deemonit ja init-protsessi ei puudutata kunagi.

### Intsident 3 — volitamata port 4444 `kiosk-lobby`
- **Rünne:** `python3 -m http.server 4444`
- **Avastamine:** `listening_ports JOIN processes`; seadme lubatud pordid on `[22]` → `PORT 4444 (python3, 0.0.0.0)`
- **Reageerimine:** `ss -ltnup` → pordi omanik-protsess tapetakse (`killed 'python3' (pid 1976)`).
  Lisaks rakendab 07 uuesti `04_hardening.yml`, mis taastab ka rikutud SSH-konfiguratsiooni
  (ründeskripti kommentaar „rikutakse SSH konfiguratsioon“).

### Intsident 4 — „lunavara“ kustutab finantsfailid `ws-fin-01`
- **Rünne:** `rm -rf /home/raamatupidaja/Raamatupidamine_2026/*`
- **Avastamine:** failide kadu on näha CMDB-s / taastes (failide arv 3 → 0). *Ülesanne nõuab selle
  intsidendi puhul taastet, mitte automaatset tuvastust.*
- **Reageerimine (taaste):**
  1. backup-vault: uusim `ws-fin-01/*.tar.gz.enc` + `.sha256` → hq-controllerisse
  2. hq-controller: `sha256sum -c` ✔ → `openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000` võtmega, mis on **ainult** hq-controlleris
  3. ws-fin-01: `tar -xzf … --skip-old-files` (vahepeal muudetud uuemaid faile ei kirjutata üle)
  4. dekrüpteeritud koopia kustutatakse kohe nii kliendist kui hq-controllerist
- **Kontroll:** 3 faili tagasi, omanik `raamatupidaja`, õigused `0600`; `arved_2026_Q1.csv`
  SHA-256 `41f3035c…` on **identne** originaaliga.

## 4. Juurpõhjused ja õppetunnid

| # | Leid | Mõju | Parandus |
|---|---|---|---|
| 1 | **Rocky Linux 9 vaikimisi `coreutils-single`**: `/bin/sleep` on skript-ümbris `/usr/bin/coreutils` ümber. Kaevuri koopia käivitas tegelikult `coreutils`-i, mis on kettal olemas → `on_disk = 0` **ei leidnud** kaevurit (esimesel proovikorral jäi intsident 2 avastamata). | avastamata pahavara | (a) Rocky image'is täis-`coreutils`; (b) uus HIDS-reegel „protsess /tmp, /var/tmp, /dev/shm alt“ — püüab kaevuri ka `coreutils-single` korral. Mõlemad testitud. |
| 2 | **Ülesande skripti intsident 4:** `docker exec ws-fin-01 rm -rf …/*` käivitatakse ilma shellita → `*` ei laiene, `rm` otsib faili nimega `*` ja **ei kustuta midagi**. | õppus ei testiks taastet | Meie koopias `sh -c 'rm -rf …/*'` (originaal on kommentaarina alles). 07 töötab mõlemal juhul (taastab ainult puuduvad failid). |
| 3 | Häire-reegel leidis algul **iseennast** (`osqueryi` käsureal on tekst `/tmp/`). | valehäire | `name != 'osqueryi'` |
| 4 | Varukoopia on nii värske kui viimane `06` käivitus (cron 02:15). | andmekadu kuni 24 h | Raamatupidaja seadmele tihedam varundus (nt iga tund) — edasiarendus |

## 5. Mis töötas hästi
- Kahekordne tuvastus (FIM + UID=0) — tagaust ei saa varjata ainult ühe kontrolli petmisega.
- Krüptovõti ei ole kunagi varundusserveris → backup-vault'i kompromiteerimine ei lekita andmeid.
- Self-healing (cron iga 10 min) parandaks SSH/kioski triivi ka ilma inimeseta; audit iga 5 min uuendab armatuurlauda automaatselt.
- Kogu taaste on üks käsk ja idempotentne: korduv käivitamine ei tee kahju.

## 6. Ründeskript (allikas: ülesanne KS 7.0, 4. nädal)

```bash
docker exec iot-cam-1 sh -c "echo 'shadow_admin:x:0:0:root:/root:/bin/bash' >> /etc/passwd"
docker exec -d srv-app-01 sh -c "cp /bin/sleep /tmp/xmr_miner && /tmp/xmr_miner 7200 & sleep 1 && rm -f /tmp/xmr_miner"
docker exec -d kiosk-lobby sh -c "python3 -m http.server 4444 >/dev/null 2>&1 &"
docker exec ws-fin-01 rm -rf /home/raamatupidaja/Raamatupidamine_2026/*
```

## 7. Kaitsmise käsud

```bash
bash scripts/chaos_attack.sh                                                     # (või õpetaja skript)
docker exec hq-controller ansible-playbook playbooks/05_security_audit.yml       # → http://localhost:8080 punane
docker exec hq-controller ansible-playbook playbooks/07_incident_response.yml    # → roheline, failid tagasi
docker exec ws-fin-01 ls -l /home/raamatupidaja/Raamatupidamine_2026             # kontroll
```

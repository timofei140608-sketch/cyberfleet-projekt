# Milestone checklist — kontrollis: Herman Shkutenko, 27.11.2026

Testitud Windowsis (Docker Desktop + WSL 2, Git Bash / PowerShell).

## Nädal 1
- [x] `docker compose ps` — 8 konteinerit `Up`
- [x] `docker exec iot-sensor-1 ping -c 2 ws-fin-01` — EI tööta (`bad address`)
- [x] `docker exec hq-controller ping -c 2 ws-fin-01` — töötab
- [x] `docker exec hq-controller ansible all -m ping` — 7 × SUCCESS

Tõendid: `week1_commander_check.png`

## Nädal 2
- [x] http://localhost:8080 — CMDB tabel, 8 seadet, OS / RAM / paketid / pordid
- [x] `docker exec kiosk-lobby su - kiosk -c 'cd /etc'` → `restricted`

Tõendid: `week2_dashboard_clean.png`, `week2_kiosk_restricted.png`

## Nädal 3
- [x] Parooliga SSH ei tööta pärast 04 (`Permission denied (publickey)`)
- [x] `docker exec backup-vault ls /srv/backups` — 4 seadme kaustad, failid `.enc` + `.sha256`

Tõendid: `week3_backup_playbook_done.png`, `week3_vault_backups.png`

## Nädal 4
- [x] `chaos_attack.sh` → 05 → armatuurlaual 5 punast häiret (shadow_admin, xmr_miner, port 4444, FIM /etc/passwd)
- [x] 07 → roheline, `Raamatupidamine_2026` — 3 faili taastatud
- [x] Aeg rünnakust taasteni: 198 s (09:05:13 → 09:08:31)

Tõendid: `week4_attack_start_time.png`, `week4_05_audit_start.png`, `week4_05_audit_findings.png`,
`week4_dashboard_under_attack.png`, `week4_dashboard_recovered.png`,
`week4_07_fin_files_restored.png`, `week4_recovery_time.png`

Märkused: Märkused: kõik kontrollid tehtud ühes jooksus 27.11.2026. Windowsis tuli Git Bashi asemel kasutada PowerShelli (docker käsud) ja Git Bashi täispolgu (`setup.sh`, `chaos_attack.sh`).

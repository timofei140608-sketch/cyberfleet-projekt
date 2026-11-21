# Kioski profiil
- shell `/bin/rbash` (restricted bash): `cd` keelatud, `PATH`/`SHELL`/`ENV` muutmine keelatud
- kodukataloog ja `.bash_profile` kuuluvad root'ile (kasutaja ei saa profiili muuta)
- `PATH` = `/home/kiosk/bin` (ainult lubatud käsud symlinkidena), `readonly`
- sudo puudub

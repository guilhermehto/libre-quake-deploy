# LibreQuake server (FTEQW) for Dokploy

QuakeWorld deathmatch server: FTEQW dedicated built from source + LibreQuake `server.zip` (v0.09-beta).

## Deploy on Dokploy
1. Push this repo to GitHub/Gitea.
2. Dokploy → Create Service → **Compose** → point at repo, compose path `docker-compose.yml`.
3. Environment tab: `RCON_PASSWORD=<something long>`.
4. Deploy. No domain needed — UDP bypasses Traefik.
5. Open **UDP 27500** in VPS firewall (ufw/cloud panel).

## Connect
FTEQW client with LibreQuake installed → console (`~`):
```
connect <vps-ip>:27500
```

## Config
- Edit `config/server.cfg` → redeploy. Rotation, frag/time limits, maxclients there.
- Public server list: `sv_public 1`.
- Remote admin from client console: `rcon_password <pw>` then `rcon changelevel lqdm3`.

## Upgrade
Change `LQ_VERSION` build arg in compose. Pin `FTEQW_REF` to a commit/tag for reproducible builds.

## Notes
- Clients should run same LibreQuake version (`sv_mapcheck 0` relaxes this).
- Logs show `Unable to load maps/b_*.bsp` — item box models not in server.zip; harmless on server.

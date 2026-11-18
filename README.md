# vps-infra

What runs on my VPS: one Caddy that owns ports 80/443 and routes by hostname, plus the services behind it.

```
Internet → caddy (HTTPS) ─┬─ RALLY_HOST → rally-web:8080   (Go server, built from ../rally-point)
                          ├─ STATS_HOST → goatcounter:8080 (analytics, SQLite in a volume)
                          └─ MONITOR_HOST → beszel:8090    (server monitoring; data in ../beszel)
```

Only `caddy` publishes public ports (`beszel` also binds 8090 on 127.0.0.1, for SSH tunnels). The other services are reached by service name on the network compose creates.

## First setup on the server

1. Check out this repo and `rally-point` side by side, with Beszel's data folder next to them:
   ```
   ~/apps/vps-infra
   ~/apps/rally-point
   ~/apps/beszel        # beszel_data, beszel_agent_data, beszel_socket (not in git)
   ```
2. Point DNS records for both hostnames at the VPS.
3. `cp .env.example .env` and set `RALLY_HOST`, `STATS_HOST`, `MONITOR_HOST` and `BESZEL_HUB_PUBLIC_KEY`.
4. Start everything: `make up`
5. Create the GoatCounter site and login (asks for a password interactively):
   ```
   docker compose run --rm goatcounter db create site -createdb \
     -vhost <STATS_HOST> -user.email <you@example.com>
   ```
   Then log in at `https://<STATS_HOST>`.
6. Nothing to add to the app: `compose.yaml` passes `https://<STATS_HOST>/count` to the app's build, and the frontend then loads GoatCounter and reports each page and route change. The app only counts when built this way (not in local dev).

## Deploying an update to the app

```
cd ~/apps/rally-point && git pull
cd ~/apps/vps-infra && make up SERVICE=rally-web
```

`make up` asks git (in `rally-point`) for the backend's version and passes it to the build, so `https://<RALLY_HOST>/api/version` reports what is deployed (for example `1.0.0`, or `1.0.0-3-gabc1234` when it is 3 commits past the tag). Plain `docker compose up --build` also works, but then the version shows as `dev`. To give the backend a release number, tag it in the `rally-point` repo: `git tag backend/v1.0.0 && git push origin backend/v1.0.0`.

## Adding another app

1. Add a service to `compose.yaml` (no `ports`).
2. Add a block to `Caddyfile` with `reverse_proxy <service>:<port>`, and a `*_HOST` variable in `.env` / `.env.example` / the caddy `environment`.
3. Add the DNS record, then `make up`.

## Monitoring (Beszel)

`beszel` (hub + web UI) is served at `https://<MONITOR_HOST>` and protected by Beszel's own login. `beszel-agent` runs with host networking and reports to the hub over a unix socket in `../beszel/beszel_socket`. The agent's `KEY` is the hub's public key: in the Beszel UI, Add system shows it. On a fresh server with no `../beszel/beszel_data`, start the stack, create the Beszel admin account, copy the key into `.env`, add the system with host `/beszel_socket/beszel.sock`, then `make up SERVICE=beszel-agent`.

## Backups

The data worth keeping is the `goatcounter_data` volume (analytics), `caddy_data` (certificates; re-issued automatically if lost) and `../beszel/beszel_data` (monitoring history and the hub's key).

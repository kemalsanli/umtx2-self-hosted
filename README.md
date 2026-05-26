# umtx2-self-hosted

Self-hosted runner for [kemalsanli/umtx2](https://github.com/kemalsanli/umtx2) — a web-based PS5 jailbreak host.

This repo contains only the deployment scaffolding (nginx + git + cron in a Docker container). The actual jailbreak content is cloned at runtime from the upstream `umtx2` repo and pulled every 12 hours so your instance stays in sync without rebuilding the image.

## What you get

- `docker compose up -d` and you're done
- Auto-updates every 12 hours from the upstream repo (06:00 and 18:00 in the container's timezone)
- Works on a LAN with no extra setup; add your own reverse proxy if you want HTTPS / a public URL
- No payload binaries stored in this repo — everything is pulled fresh from upstream

## Quick start (LAN)

Requires Docker 20.10+ with Compose v2.

```sh
git clone https://github.com/kemalsanli/umtx2-self-hosted.git
cd umtx2-self-hosted
cp .env.example .env        # optional; edit if you want a different port
docker compose up -d --build
```

Then on your PS5 browser, navigate to:

```
http://<your-server-ip>:8080
```

Confirm it's healthy from another machine on the LAN:

```sh
curl http://<your-server-ip>:8080/healthz
# -> ok
```

## Offline install (no internet on the server)

If the server hosting the container can't reach GitHub, grab one of the
self-contained bundles from the [Releases](https://github.com/kemalsanli/umtx2-self-hosted/releases)
page. Each release ships a `bundle-YYYY.MM.DD-<sha>.tar.gz` (and `.zip`)
with the scaffolding **plus** a frozen snapshot of the upstream `umtx2`
content baked in, so no runtime clone is needed.

```sh
# On any machine with internet — download the bundle
curl -LO https://github.com/kemalsanli/umtx2-self-hosted/releases/latest/download/<TAG>.tar.gz

# Move it to the offline server (USB / scp / whatever), then:
tar xzf <TAG>.tar.gz
cd <TAG>
docker compose up -d --build
```

A new bundle is built automatically whenever upstream `umtx2` gets new
commits (twice a day via the [`build-bundle`](.github/workflows/build-bundle.yml)
workflow). To upgrade, drop a newer bundle in and re-run
`docker compose up -d --build`.

## Configuration

All knobs are env vars (set in `.env` or `docker compose` overrides):

| Variable          | Default                                        | Notes                                            |
|-------------------|------------------------------------------------|--------------------------------------------------|
| `HOST_PORT`       | `8080`                                         | Host-side port mapped to nginx:80                |
| `REPO_URL`        | `https://github.com/kemalsanli/umtx2.git`      | Override to point at a fork                      |
| `REPO_REF`        | `main`                                         | Branch or tag. Pin a tag for reproducibility     |
| `TZ`              | `UTC`                                          | Affects when the 06:00/18:00 cron pulls run      |

## Updates

The container's internal cron pulls the upstream repo twice a day. You can also trigger one manually:

```sh
docker compose exec umtx2 /usr/local/bin/update.sh
```

To check what's currently deployed:

```sh
docker compose exec umtx2 git -C /srv/umtx2 log --oneline -5
```

## HTTPS / public exposure

This image only speaks HTTP on port 80 (mapped to your chosen `HOST_PORT`). If you want a public URL with HTTPS, put a reverse proxy in front. Popular options:

- **Caddy** — auto-issues Let's Encrypt certs:
  ```caddy
  umtx2.example.com {
      reverse_proxy localhost:8080
  }
  ```
- **Cloudflare Tunnel** — zero-port-forwarding, free TLS at the edge
- **nginx + certbot** — classic setup

## Notes

- **Switching between hosts wipes the PS5 AppCache.** The PS5 browser stores an AppCache per origin. If you used to load this from GitHub Pages, the PS5 will still hold that old cache for that origin — that's fine, your new self-hosted origin starts a fresh cache. If you want to clear the old cache, send the `appcache-remove` payload from the GitHub-Pages-hosted UI before switching.
- **Pinning a version:** set `REPO_REF` to a specific tag (e.g. `REPO_REF=v2.1.1`) for reproducible deploys; the cron pull then becomes a no-op.
- **Offline operation:** the container needs internet for the initial clone and for cron updates. Once content is in place, nginx keeps serving even with no internet — the fetch/pull paths in `entrypoint.sh` and `update.sh` are best-effort and won't kill the container if GitHub is unreachable. For a truly air-gapped deploy, prefer the [offline install](#offline-install-no-internet-on-the-server) flow above.

## Troubleshooting

```sh
# logs
docker compose logs -f

# inspect the cloned repo
docker compose exec umtx2 ls /srv/umtx2/document/en/ps5

# tail cron output
docker compose exec umtx2 tail -f /var/log/cron.log

# rebuild after editing nginx.conf / Dockerfile
docker compose up -d --build
```

## License

This scaffolding is MIT. The mirrored content is whatever license the upstream `umtx2` repo carries (currently MIT).

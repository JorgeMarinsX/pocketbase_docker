# PocketBase Docker

Latest pocketbase: **v0.40.4** (linux/amd64 binary in this repo).

Packages the `pocketbase` binary into an image on GitHub Container Registry (GHCR), deployed as a Portainer stack behind Traefik.

## Release

Push a tag named `vX.Y.Z-prod`:

```sh
git tag v0.0.1-prod
git push origin v0.0.1-prod
```

The [Production image](.github/workflows/production.yml) workflow builds the image and pushes it with two tags:

- `ghcr.io/jorgemarinsx/pocketbase_docker:0.0.1-prod`
- `ghcr.io/jorgemarinsx/pocketbase_docker:latest`

Other tag names don't trigger it. The build runs `pocketbase --version`, so a missing or wrong-arch binary fails the build.

New GHCR packages are private. You can check this under your GitHub profile → Packages → `pocketbase_docker` → Package settings.

To build locally for testing: `docker build --platform linux/amd64 -t pocketbase:dev .`

## Deploy in Portainer

1. **Registries**: add `ghcr.io` with your GitHub username and a classic personal access token with the `read:packages` scope (GHCR doesn't accept fine-grained tokens).
2. **Stacks → Add stack → Web editor**: paste [docker-compose.yml](docker-compose.yml).
3. **Environment variables**: set the values from [.env.example](.env.example) (or use "Load variables from .env file").
4. Deploy.

| Variable | Default | Purpose |
|---|---|---|
| `PB_IMAGE` | required | Image to run, e.g. `ghcr.io/jorgemarinsx/pocketbase_docker:0.0.1-prod` |
| `PB_DOMAIN` | required | Public hostname, e.g. `api.example.com` |
| `PB_NAME` | `pocketbase` | Traefik router/service name. Must be unique per PocketBase stack |
| `TRAEFIK_NETWORK` | `traefik` | Existing external network Traefik is attached to |
| `TRAEFIK_ENTRYPOINT` | `websecure` | Traefik HTTPS entrypoint name |
| `TRAEFIK_CERTRESOLVER` | `letsencrypt` | Traefik certificate resolver name |
| `PB_ENCRYPTION_KEY` | empty | Optional 32-char key that encrypts stored settings (SMTP/S3 secrets) |
| `PB_SUPERUSER_EMAIL` | empty | Optional. First superuser, created on the first deploy only |
| `PB_SUPERUSER_PASSWORD` | empty | Optional. At least 8 chars |

HTTP to HTTPS redirection is left to Traefik's entrypoint config. Traefik v3 has a 60s default `readTimeout` on entrypoints; raise it if users upload large files over slow links.

If you set `PB_ENCRYPTION_KEY`, do it before the first start and keep a copy: without it, the settings can't be read.

## First superuser

Set `PB_SUPERUSER_EMAIL` and `PB_SUPERUSER_PASSWORD` before the first deploy. The image ships a JS migration ([PocketBase's documented pattern](https://pocketbase.io/docs/js-migrations/)) that creates this superuser when the database is new. Like any migration it runs once, so on later deploys the variables do nothing: changing them won't reset the password or add another account. Change the password in the dashboard after the first login. If the password is invalid (under 8 chars), the container stops and logs the reason.

If you deployed without them, use one of these instead:

- Open the installer link printed in the container logs, replacing `http://0.0.0.0:8090` with `https://<PB_DOMAIN>`.
- Open the container **Console** in Portainer (`/bin/sh`) and run:

  ```sh
  /pb/pocketbase superuser upsert you@example.com 'StrongPassword' --encryptionEnv=PB_ENCRYPTION_KEY
  ```

Always pass `--encryptionEnv=PB_ENCRYPTION_KEY` to CLI commands inside the container. It does nothing when no key is set, but they fail without it once a key is set.

The dashboard is at `https://<PB_DOMAIN>/_/`.

## After the first login (Dashboard → Settings)

- **Application → Trusted proxy**: add the `X-Forwarded-For` header and leave "use leftmost IP" off. Without this, logs and rate limits see Traefik's IP instead of the client's.
- Recommended by the [production guide](https://pocketbase.io/docs/going-to-production/): SMTP mail server, rate limiting, MFA for superusers, and scheduled backups (local or S3).

## Volumes

| Volume | Path | Contents |
|---|---|---|
| `pb_data` | `/pb/pb_data` | SQLite DBs, uploaded files, local backups. **This is what you back up.** |
| `pb_public` | `/pb/pb_public` | Static files served at `/` (e.g. a SPA build) |
| `pb_hooks` | `/pb/pb_hooks` | JS hooks (`*.pb.js`), reloaded automatically on change |
| `pb_migrations` | `/pb/pb_migrations` | JS migrations, auto-generated when collections change in the dashboard. Seeded with `0_superuser_from_env.js` on first deploy |

To add hooks or static files to a named volume:

```sh
docker cp main.pb.js <container>:/pb/pb_hooks/
```

The container runs as uid/gid `1000`. To switch to bind mounts (host paths), run `chown -R 1000:1000` on those host folders first. Bind mounts aren't seeded from the image, so the superuser migration won't be there; use the installer link or CLI instead.

## Updating PocketBase

1. Back up first: Dashboard → Settings → Backups.
2. Replace `pocketbase` in this repo with the new linux amd64 binary from the [releases](https://github.com/pocketbase/pocketbase/releases), and update the version at the top of this file.
3. Commit, then push a new `vX.Y.Z-prod` tag (see [Release](#release)).
4. In Portainer, update `PB_IMAGE` to the new tag and redeploy the stack with "Re-pull image". Volumes are kept.

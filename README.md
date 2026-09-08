# x-dockhand-agent

Deploys a [Dockhand](https://github.com/finsys) agent (`ghcr.io/finsys/hawser`) on a host, connecting it to a central Dockhand dashboard so the host's Docker stacks can be managed remotely.

## Requirements

- Docker Engine + Docker Compose plugin
- A running Dockhand Main dashboard (to get `DH_MAIN_HOSTNAME` and a `DH_TOKEN`)

## Quick start

```bash
git clone <this-repo-url> x-dockhand-agent
cd x-dockhand-agent
bash bootstrap.sh
```

`bootstrap.sh` will:

1. Create `.env` from `.env.example` if it doesn't exist yet
2. Prompt you (interactively, values not saved to shell history) for any required variable that's missing or still a placeholder
3. Create the external Docker volume (`x-dockhand-stacks_<DH_AGENT_NAME>`) if it doesn't exist
4. Run `docker compose up -d`

Safe to re-run: already-set variables and already-existing volumes are skipped.

## Environment variables

| Variable | Description |
| --- | --- |
| `CT_HOSTNAME` | Hostname reported by the container |
| `DH_AGENT_NAME` | Name shown for this agent in the Dockhand dashboard; also used to name its backup volume (`x-dockhand-stacks_<DH_AGENT_NAME>`) |
| `DH_MAIN_HOSTNAME` | Hostname of your Dockhand Main dashboard |
| `DH_TOKEN` | Auth token for this agent — get it from the Dockhand dashboard under *Environments* |

Copy `.env.example` to `.env` and fill these in — or just run `bootstrap.sh`, which will ask for anything missing.

## Manual setup (without bootstrap.sh)

```bash
docker volume create x-dockhand-stacks_<DH_AGENT_NAME>
cp .env.example .env
nano .env   # fill in the variables above
docker compose up -d
```

## Notes

- The volume is `external: true` on purpose — a `docker compose down` (even `down -v`) won't touch it. It has to be removed manually with `docker volume rm` if you no longer need the backups.
- The container mounts `/var/run/docker.sock`, giving it full control over Docker on that host. Only deploy this on machines you intend to manage through Dockhand.

## Future feature mental note :)

- to add optional systemd service + timer for git reset --hard origin/main
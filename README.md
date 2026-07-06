# Imbai Worker — client install from GitHub

Public repo: https://github.com/array05/IMBACLOUD-AI

## Client install (one command)

Get `--registration-token` from your Imbai admin, then:

```bash
curl -fsSL https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh | bash -s -- \
  --worker-id YOUR_WORKER_ID \
  --workspace /var/www/myapp \
  --registration-token YOUR_ONE_TIME_TOKEN \
  --gateway http://31.129.101.206:8080
```

No gateway SSH or root password needed.

## Non-root install

```bash
curl -fsSL https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh | bash -s -- \
  --worker-id YOUR_WORKER_ID \
  --workspace /home/deploy/app \
  --registration-token TOKEN \
  --user deploy
```

## What it does

1. Downloads worker from this repo
2. Installs Python worker on **your** server
3. Registers with Imbai gateway via HTTPS
4. Sends heartbeat every 30s

## Firewall

Open port **9090** on your server for gateway IP only: `31.129.101.206`

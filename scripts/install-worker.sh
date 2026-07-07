#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEFAULT_GATEWAY="http://31.129.101.206:8080"
DEFAULT_WORKSPACE="/root"
DEFAULT_PORT=9090
MODE="native"
RUN_AS_USER=""

usage() {
  cat <<EOF
Usage: $(basename "$0") --worker-id ID --registration-token TOKEN [options]

Required:
  --worker-id ID              Worker name (e.g. client-prod)
  --registration-token TOKEN  One-time token from admin (NOT gateway password)

Optional:
  --workspace PATH            Workspace on this server (default: ${DEFAULT_WORKSPACE})
  --url URL                   Public URL (default: auto-detect IP + port)
  --gateway URL               Gateway (default: ${DEFAULT_GATEWAY})
  --port PORT                 Port (default: ${DEFAULT_PORT})
  --token TOKEN               Worker auth token (auto-generated)
  --user USER                 Install as non-root user (no root on client server)
  --docker                    Docker mode (not recommended)
  --help

Install from GitHub (client, no gateway SSH):
  curl -fsSL https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh | bash -s -- \\
    --worker-id client-prod --registration-token TOKEN

Platform: https://imbacloud.ru/
EOF
}

detect_public_ip() {
  local ip=""
  for svc in "https://ifconfig.me" "https://icanhazip.com" "https://api.ipify.org"; do
    ip="$(curl -sf --max-time 5 "$svc" 2>/dev/null | tr -d '[:space:]')" && [[ -n "$ip" ]] && break
  done
  if [[ -z "$ip" ]]; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
  echo "$ip"
}

generate_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    python3 -c "import secrets; print(secrets.token_urlsafe(32))"
  fi
}

write_env_worker() {
  cat > .env.worker <<EOF
WORKER_TOKEN=${WORKER_TOKEN}
WORKER_WORKSPACE=${WORKER_WORKSPACE}
WORKER_PORT=${WORKER_PORT}
SHELL_TIMEOUT=120

WORKER_ID=${WORKER_ID}
WORKER_PUBLIC_URL=${WORKER_PUBLIC_URL}
GATEWAY_URL=${GATEWAY_URL}
REGISTRATION_TOKEN=${REGISTRATION_TOKEN}
HEARTBEAT_INTERVAL=30
EOF
}

register_worker() {
  echo "Registering with gateway ${GATEWAY_URL}..."
  local register_payload
  register_payload="$(WORKER_ID="$WORKER_ID" WORKER_PUBLIC_URL="$WORKER_PUBLIC_URL" \
    WORKER_TOKEN="$WORKER_TOKEN" WORKER_WORKSPACE="$WORKER_WORKSPACE" python3 - <<'PY'
import json, os
print(json.dumps({
    "worker_id": os.environ["WORKER_ID"],
    "url": os.environ["WORKER_PUBLIC_URL"],
    "token": os.environ["WORKER_TOKEN"],
    "workspace": os.environ["WORKER_WORKSPACE"],
}))
PY
)"
  curl -sf -X POST "${GATEWAY_URL%/}/v1/workers/register" \
    -H "Authorization: Bearer ${REGISTRATION_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$register_payload"
  echo
}

install_native() {
  if [[ "$(id -u)" -ne 0 ]]; then
    install_native_user
    return
  fi

  apt-get update -qq
  apt-get install -y -qq python3 python3-venv python3-pip curl

  python3 -m venv .venv
  .venv/bin/pip install -q --upgrade pip
  .venv/bin/pip install -q -r worker/requirements.txt

  mkdir -p "$WORKER_WORKSPACE"
  chmod 755 "$WORKER_WORKSPACE"

  sed "s|\${WORKER_PORT}|${WORKER_PORT}|g" scripts/imbai-worker.service > /etc/systemd/system/imbai-worker.service
  systemctl daemon-reload
  systemctl enable imbai-worker
  systemctl restart imbai-worker

  wait_for_health "journalctl -u imbai-worker -n 50"
}

install_native_user() {
  local user="${RUN_AS_USER:-$(id -un)}"
  local home
  home="$(eval echo "~${user}")"

  if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 required. Install: apt install python3 python3-venv" >&2
    exit 1
  fi

  python3 -m venv .venv
  .venv/bin/pip install -q --upgrade pip
  .venv/bin/pip install -q -r worker/requirements.txt

  mkdir -p "$WORKER_WORKSPACE"

  local unit_dir="${home}/.config/systemd/user"
  mkdir -p "$unit_dir"
  sed "s|\${WORKER_PORT}|${WORKER_PORT}|g; s|%i|${ROOT}|g" scripts/imbai-worker-user.service > "${unit_dir}/imbai-worker.service"

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable imbai-worker
    systemctl --user restart imbai-worker
    echo "Tip: run once as root for persistent service: loginctl enable-linger ${user}"
  else
    (cd worker && PYTHONPATH="${ROOT}:${ROOT}/worker" nohup "${ROOT}/.venv/bin/uvicorn" app.main:app \
      --host 0.0.0.0 --port "${WORKER_PORT}" > "${ROOT}/worker.log" 2>&1 &)
    echo "Started worker in background (nohup). Log: ${ROOT}/worker.log"
  fi

  wait_for_health "cat ${ROOT}/worker.log"
}

wait_for_health() {
  local err_cmd="$1"
  echo "Waiting for worker..."
  for _ in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:${WORKER_PORT}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Worker failed to start. Check: ${err_cmd}" >&2
  exit 1
}

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq docker.io docker-compose-v2
  fi
  mkdir -p "$WORKER_WORKSPACE"
  chmod 755 "$WORKER_WORKSPACE"
  docker compose -f docker-compose.worker.yml up -d --build
  for _ in $(seq 1 45); do
    if curl -sf "http://127.0.0.1:${WORKER_PORT}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Docker worker failed. Check: docker logs imbai-worker" >&2
  exit 1
}

WORKER_ID=""
WORKER_WORKSPACE=""
WORKER_PUBLIC_URL=""
GATEWAY_URL="${IMBAI_GATEWAY:-${DEFAULT_GATEWAY}}"
REGISTRATION_TOKEN="${IMBAI_REGISTRATION_TOKEN:-}"
WORKER_PORT="${DEFAULT_PORT}"
WORKER_TOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worker-id) WORKER_ID="$2"; shift 2 ;;
    --workspace) WORKER_WORKSPACE="$2"; shift 2 ;;
    --url) WORKER_PUBLIC_URL="$2"; shift 2 ;;
    --gateway) GATEWAY_URL="$2"; shift 2 ;;
    --registration-token) REGISTRATION_TOKEN="$2"; shift 2 ;;
    --port) WORKER_PORT="$2"; shift 2 ;;
    --token) WORKER_TOKEN="$2"; shift 2 ;;
    --user) RUN_AS_USER="$2"; shift 2 ;;
    --docker) MODE="docker"; shift ;;
    --native) MODE="native"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$WORKER_ID" ]]; then
  echo "Error: --worker-id is required." >&2
  usage
  exit 1
fi

if [[ -z "$WORKER_WORKSPACE" ]]; then
  WORKER_WORKSPACE="${DEFAULT_WORKSPACE}"
  echo "Using default workspace: ${WORKER_WORKSPACE}"
fi

if [[ -z "$REGISTRATION_TOKEN" ]]; then
  echo "Error: --registration-token required (get from admin: issue-client-token.sh)" >&2
  exit 1
fi

if [[ ! "$WORKER_WORKSPACE" = /* ]]; then
  echo "Error: --workspace must be an absolute path." >&2
  exit 1
fi

if [[ -z "$WORKER_TOKEN" ]]; then
  WORKER_TOKEN="$(generate_token)"
fi

if [[ -z "$WORKER_PUBLIC_URL" ]]; then
  IP="$(detect_public_ip)"
  if [[ -z "$IP" ]]; then
    echo "Error: could not detect public IP. Pass --url http://YOUR_IP:${WORKER_PORT}" >&2
    exit 1
  fi
  WORKER_PUBLIC_URL="http://${IP}:${WORKER_PORT}"
  echo "Auto-detected URL: ${WORKER_PUBLIC_URL}"
fi

write_env_worker
echo "Wrote .env.worker (mode: ${MODE})"

if [[ "$MODE" == "native" ]]; then
  install_native
else
  install_docker
fi

register_worker

echo "Done (${MODE})."
echo "  worker_id:  ${WORKER_ID}"
echo "  url:        ${WORKER_PUBLIC_URL}"
echo "  workspace:  ${WORKER_WORKSPACE}  (HOST filesystem)"
echo "  mode:       ${MODE}"
echo
echo "Verify on gateway:"
echo "  curl -H 'Authorization: Bearer YOUR_API_KEY' ${GATEWAY_URL%/}/v1/workers"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/github-worker-publish"

rm -rf "$OUT"
mkdir -p "$OUT"

cp "${ROOT}/install.sh" "$OUT/"
cp "${ROOT}/docker-compose.worker.yml" "$OUT/"
cp "${ROOT}/.env.worker.example" "$OUT/"
cp -r "${ROOT}/worker" "${ROOT}/shared" "${ROOT}/scripts" "$OUT/"

# Only client-facing scripts in published repo
rm -f "$OUT/scripts/issue-client-token.sh" "$OUT/scripts/bundle-worker.sh" "$OUT/scripts/healthcheck.sh"

cat > "$OUT/README.md" <<'EOF'
# Imbai Worker

Install on **your server** (not the gateway). No gateway credentials needed.

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/imbai-worker/main/install.sh | bash -s -- \
  --worker-id YOUR_WORKER_ID \
  --registration-token TOKEN_FROM_ADMIN
```

Get `TOKEN_FROM_ADMIN` from your Imbai provider.
EOF

echo "Published to: $OUT"
echo "Push to GitHub:"
echo "  cd $OUT && git init && git add . && git commit -m 'imbai worker' && git remote add origin git@github.com:YOUR_ORG/imbai-worker.git && git push -u origin main"

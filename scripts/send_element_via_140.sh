#!/usr/bin/env bash
# Envoie un message texte sur le canal Element (Matrix) via la VM 140.
# Usage:
#   echo "hello" | bash scripts/send_element_via_140.sh
#   bash scripts/send_element_via_140.sh "hello"
set -euo pipefail

HOST="${LBG_MATRIX_SSH_HOST:-lbg@192.168.0.140}"
MSG="${1:-}"
if [ -z "$MSG" ]; then
  MSG="$(cat)"
fi
MSG="${MSG%"${MSG##*[![:space:]]}"}"
if [ -z "$MSG" ]; then
  echo "message vide" >&2
  exit 1
fi

# Passage via env distant (évite quoting foireux) — base64
B64=$(printf '%s' "$MSG" | base64 -w0 2>/dev/null || printf '%s' "$MSG" | base64)

ssh -o BatchMode=yes -o ConnectTimeout=10 "$HOST" "MSG_B64='$B64' bash -s" <<'REMOTE'
set -euo pipefail
set -a
# shellcheck disable=SC1091
source /etc/lbg-project-03.env
set +a
cd /opt/lbg_project_03
export PYTHONPATH=/opt/lbg_project_03
PY=/opt/lbg_project_03/.venv/bin/python
[ -x "$PY" ] || PY=python3
"$PY" - <<'PY'
import base64, os, sys
from lbg_agents.matrix_client import MatrixClient
from lbg_agents.matrix_config import MatrixConfig

raw = os.environ.get("MSG_B64", "")
text = base64.b64decode(raw.encode("ascii")).decode("utf-8", errors="replace").strip()
if not text:
    print("empty", file=sys.stderr)
    raise SystemExit(2)
cfg = MatrixConfig.from_env()
if not cfg.configured:
    print("matrix_not_configured", file=sys.stderr)
    raise SystemExit(3)
c = MatrixClient(cfg.homeserver, access_token=cfg.access_token, user_id=cfg.user_id)
out = c.send_text(cfg.room_id, text[:60000])
print(out)
raise SystemExit(0 if out.get("ok") else 1)
PY
REMOTE

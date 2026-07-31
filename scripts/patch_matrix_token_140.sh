#!/usr/bin/env bash
# Met à jour LBG_MATRIX_ACCESS_TOKEN sur 140 et redémarre le bridge.
# Usage (ne pas coller le token dans le chat public) :
#   LBG_MATRIX_ACCESS_TOKEN='syt_...' bash scripts/patch_matrix_token_140.sh
set -euo pipefail
HOST="${LBG_MATRIX_SSH_HOST:-lbg@192.168.0.140}"
TOKEN="${LBG_MATRIX_ACCESS_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "Définir LBG_MATRIX_ACCESS_TOKEN=..." >&2
  exit 1
fi
# escape for sed replacement
ESC=$(printf '%s' "$TOKEN" | sed -e 's/[\/&]/\\&/g')
ssh -o BatchMode=yes "$HOST" "TOKEN_ESC='$ESC' bash -s" <<'REMOTE'
set -euo pipefail
ENV=/etc/lbg-project-03.env
sudo sed -i "s|^LBG_MATRIX_ACCESS_TOKEN=.*|LBG_MATRIX_ACCESS_TOKEN=${TOKEN_ESC}|" "$ENV"
sudo sed -i 's|^LBG_MATRIX_DISABLE=.*|LBG_MATRIX_DISABLE=0|' "$ENV"
sudo systemctl restart lbg-p03-matrix-bridge
sleep 2
systemctl is-active lbg-p03-matrix-bridge
# whoami check
set -a
# shellcheck disable=SC1091
source /etc/lbg-project-03.env
set +a
cd /opt/lbg_project_03
export PYTHONPATH=/opt/lbg_project_03
/opt/lbg_project_03/.venv/bin/python - <<'PY'
from lbg_agents.matrix_client import MatrixClient
from lbg_agents.matrix_config import MatrixConfig
cfg = MatrixConfig.from_env()
c = MatrixClient(cfg.homeserver, access_token=cfg.access_token, user_id=cfg.user_id)
code, body = c.whoami()
print({"whoami_status": code, "user_id": body.get("user_id"), "ok": code < 400})
raise SystemExit(0 if code < 400 else 1)
PY
REMOTE
echo "OK token patché + bridge restart"

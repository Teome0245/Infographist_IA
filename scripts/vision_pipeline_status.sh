#!/usr/bin/env bash
# Compte-rendu verbeux du pipeline vision/LoRA (stdout → Element).
# INFOGRAPHISTE_CR_VERBOSE=0 → format court
set -uo pipefail
ROOT="${INFOGRAPHISTE_ROOT:-/home/sdesh/projects/Infographiste_IA}"
STYLES="$ROOT/dataset/styles_sorted/styles"
CACHE="$ROOT/dataset/styles_sorted/.cache_vision"
STATE_DIR="/tmp/infographiste_logs"
STATE_FILE="$STATE_DIR/cr_last_snapshot.json"
VERBOSE="${INFOGRAPHISTE_CR_VERBOSE:-1}"
LOG_FILE="${INFOGRAPHISTE_PIPELINE_LOG:-}"
if [ -z "$LOG_FILE" ] && [ -f "$STATE_DIR/current_log.txt" ]; then
  LOG_FILE="$(cat "$STATE_DIR/current_log.txt" 2>/dev/null || true)"
fi
mkdir -p "$STATE_DIR"

unclassified=0
[ -d "$STYLES/unclassified" ] && unclassified=$(ls -1 "$STYLES/unclassified" 2>/dev/null | wc -l)

running="non"
run_detail="idle"
if pgrep -f 'orchestrator\.py vision-classify' >/dev/null 2>&1; then
  running="oui"
  run_detail="vision-classify en cours"
elif pgrep -f 'scripts/run_vision_prepare_pipeline\.sh' >/dev/null 2>&1; then
  running="oui"
  run_detail="pipeline bash (entre lots / prepare)"
fi

model="${OLLAMA_VISION_MODEL:-?}"
if [ -f "$ROOT/.env" ]; then
  model=$(grep -E '^OLLAMA_VISION_MODEL=' "$ROOT/.env" | head -1 | cut -d= -f2- || echo "$model")
fi

v5=$(ls "$CACHE"/v5_* 2>/dev/null | wc -l)

# Buckets complets (hors unclassified)
bucket_lines=""
bucket_total=0
if [ -d "$STYLES" ]; then
  while read -r n b; do
    [ -z "${n:-}" ] && continue
    bucket_total=$((bucket_total + n))
    bucket_lines="${bucket_lines}  • ${b}: ${n}"$'\n'
  done < <(
    for d in "$STYLES"/*/; do
      b=$(basename "$d")
      [ "$b" = "unclassified" ] && continue
      n=$(ls -1 "$d" 2>/dev/null | wc -l)
      [ "$n" -gt 0 ] && echo "$n $b"
    done | sort -nr
  )
fi

# Dernier round JSON dans le log
last_scanned="?"
last_moved="?"
last_counts="?"
last_sample="?"
round_hint=""
if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
  round_hint=$(grep -E '^ROUND |^ROUND_DONE |^PREPARE |^DONE |^backlog' "$LOG_FILE" | tail -4 | sed 's/^/  /')
  _parsed=$(
    python3 - "$LOG_FILE" <<'PY'
import json, sys
path = sys.argv[1]
try:
    text = open(path, encoding="utf-8", errors="ignore").read()
except OSError:
    raise SystemExit(0)
objs = []
buf, depth = [], 0
for ch in text:
    if ch == "{":
        if depth == 0:
            buf = ["{"]
        else:
            buf.append(ch)
        depth += 1
    elif depth > 0:
        buf.append(ch)
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                raw = "".join(buf)
                try:
                    d = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                if isinstance(d, dict) and "moved_out" in d and "scanned" in d:
                    objs.append(d)
if not objs:
    raise SystemExit(0)
d = objs[-1]
counts = d.get("counts") or {}
counts_s = ", ".join(f"{k}={v}" for k, v in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])))
sample_bits = []
for s in (d.get("sample") or [])[:5]:
    if isinstance(s, dict):
        sample_bits.append(f"{s.get('final_style','?')}({s.get('confidence',0)})")
print(d.get("scanned", "?"))
print(d.get("moved_out", "?"))
print(counts_s or "?")
print(", ".join(sample_bits) or "?")
PY
  )
  if [ -n "$_parsed" ]; then
    last_scanned=$(printf '%s\n' "$_parsed" | sed -n '1p')
    last_moved=$(printf '%s\n' "$_parsed" | sed -n '2p')
    last_counts=$(printf '%s\n' "$_parsed" | sed -n '3p')
    last_sample=$(printf '%s\n' "$_parsed" | sed -n '4p')
  fi
fi

# Delta vs snapshot précédent
delta_u="—"
delta_note=""
prev_u=""
prev_ts=""
if [ -f "$STATE_FILE" ]; then
  prev_u=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("unclassified",""))' "$STATE_FILE" 2>/dev/null || true)
  prev_ts=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("ts",""))' "$STATE_FILE" 2>/dev/null || true)
fi
if [ -n "$prev_u" ] && [ "$prev_u" -eq "$prev_u" ] 2>/dev/null; then
  delta_u=$((prev_u - unclassified))
  if [ "$delta_u" -gt 0 ]; then
    delta_note="↓ ${delta_u} depuis dernier CR"
  elif [ "$delta_u" -lt 0 ]; then
    delta_note="↑ $((-delta_u)) (remises / nouvelles)"
  else
    delta_note="stable depuis dernier CR"
  fi
fi

# Cadence approx depuis début du log courant
rate="—"
eta="—"
session_start="?"
session_done="?"
if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
  eval "$(
    python3 - "$LOG_FILE" "$unclassified" <<'PY'
import re, sys
from datetime import datetime
path, uncl = sys.argv[1], int(sys.argv[2])
try:
    lines = open(path, encoding="utf-8", errors="ignore").readlines()
except OSError:
    raise SystemExit(0)
start = None
rounds = []
for ln in lines:
    m = re.search(r"^START\s+(\S+)", ln)
    if m:
        try:
            start = datetime.fromisoformat(m.group(1))
        except ValueError:
            pass
    m = re.search(r"^ROUND\s+(\d+)\s+unclassified=(\d+)\s+(\S+)", ln)
    if m:
        try:
            rounds.append((int(m.group(1)), int(m.group(2)), datetime.fromisoformat(m.group(3))))
        except ValueError:
            pass
if not start or not rounds:
    print("rate_s='—'")
    print("eta_s='—'")
    raise SystemExit(0)
last_u, last_t = rounds[-1][1], rounds[-1][2]
# unclassified au START = premier ROUND
first_u = rounds[0][1]
elapsed_h = max((last_t - start).total_seconds() / 3600.0, 1/60)
done = max(first_u - uncl, 0)
iph = done / elapsed_h if elapsed_h > 0 else 0
print(f"rate_s='~{iph:.0f} img/h (session)'")
if iph > 0 and uncl > 0:
    rem_h = uncl / iph
    h = int(rem_h)
    m = int((rem_h - h) * 60)
    print(f"eta_s='~{h}h{m:02d}m (cadence session)'")
else:
    print("eta_s='—'")
print(f"session_start={first_u}")
print(f"session_done={done}")
PY
  )"
  rate="${rate_s:-—}"
  eta="${eta_s:-—}"
fi

# Ollama / GPU
ollama_line="—"
if command -v curl >/dev/null 2>&1; then
  ollama_line=$(
    curl -s --max-time 2 http://127.0.0.1:11434/api/ps 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print("indisponible")
    raise SystemExit(0)
ms = d.get("models") or []
if not ms:
    print("aucun modèle chargé")
else:
    print(", ".join("%s vram=%s" % (m.get("name"), m.get("size_vram", 0)) for m in ms))
' 2>/dev/null || echo "indisponible"
  )
fi
gpu_line="—"
if command -v nvidia-smi >/dev/null 2>&1; then
  gpu_line=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "n/a")
fi

now_iso=$(date -Is)
# Sauvegarder snapshot pour prochain delta
python3 - "$STATE_FILE" "$unclassified" "$bucket_total" "$now_iso" <<'PY'
import json, sys
path, u, bt, ts = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
json.dump({"unclassified": u, "bucket_total": bt, "ts": ts}, open(path, "w"), indent=2)
PY

if [ "$VERBOSE" = "0" ]; then
  cat <<EOF
📊 Infographiste — CR vision/LoRA
• running: ${running} (${run_detail})
• modèle: ${model} · unclassified: ${unclassified} (${delta_note:-—})
• buckets top: $(echo "$bucket_lines" | head -3 | tr '\n' ' ')
• ETA: ${eta}
• ts: ${now_iso}
EOF
  exit 0
fi

cat <<EOF
📊 Infographiste — compte-rendu vision / LoRA

⏱ Quand
  • ${now_iso}
  • précédent CR: ${prev_ts:-aucun}

🔄 Pipeline
  • état: ${running} — ${run_detail}
  • modèle vision: ${model} (taxonomie v5)
  • Ollama: ${ollama_line}
  • GPU: ${gpu_line}

📦 Backlog
  • unclassified: ${unclassified}
  • delta: ${delta_note:-premier CR}
  • session: traité ~${session_done:-?} depuis START (départ ~${session_start:-?})
  • cadence: ${rate}
  • ETA backlog: ${eta}
  • caches vision v5: ${v5}

🗂 Buckets styles (total classés ≈ ${bucket_total})
${bucket_lines:-  • (vide)
}
🧪 Dernier lot vision-classify
  • scanned: ${last_scanned:-?} · moved_out: ${last_moved:-?}
  • counts: ${last_counts:-?}
  • échantillon: ${last_sample:-?}

📜 Log récent
${round_hint:-  • n/a}
  • fichier: ${LOG_FILE:-n/a}

➡️ Suite prévue
  • fin backlog (<40) → prepare-styles --from-sorted
  • puis train LoRA (ex. prime_sprite_2d / mmorpg_general) si datasets prêts
EOF

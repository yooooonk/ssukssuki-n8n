#!/usr/bin/env bash
# 워크플로우 JSON <-> 서버 n8n 동기화
# 레포의 JSON에는 개인 값 대신 자리표시자(__SHEET_ID__, __GMAIL_ADDRESS__, __ALERT_TO__)만 저장하고,
# 배포할 때 .env 값으로 채운다. (.env 는 git 제외)
#
#   scripts/workflow.sh render <file>        자리표시자를 채운 JSON 출력 (확인용)
#   scripts/workflow.sh deploy <file>...     서버에 import → 활성 워크플로우 publish → n8n 재시작
#   scripts/workflow.sh export               서버 워크플로우를 workflows/ 로 내보내기 (개인 값은 자리표시자로)
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=${N8N_SSH_HOST:-dont-stock}
CONTAINER=dont-stock-n8n
set -a; . ./.env; set +a
export ALERT_TO=${ALERT_TO:-$GMAIL_ADDRESS}
KEYS="SHEET_ID GMAIL_ADDRESS ALERT_TO"

render() {
  python3 - "$1" <<'EOF'
import os, sys
s = open(sys.argv[1], encoding='utf-8').read()
for k in os.environ['KEYS'].split():
    s = s.replace(f'__{k}__', os.environ[k])
assert '__SHEET_ID__' not in s and '__GMAIL_ADDRESS__' not in s and '__ALERT_TO__' not in s, '채워지지 않은 자리표시자'
sys.stdout.write(s)
EOF
}

case "${1:-}" in
  render)
    KEYS=$KEYS render "$2"
    ;;
  deploy)
    shift
    publish=()
    for f in "$@"; do
      name=$(basename "$f")
      KEYS=$KEYS render "$f" | ssh "$HOST" "docker exec -i $CONTAINER sh -c 'cat > /tmp/$name'"
      ssh "$HOST" "docker exec $CONTAINER n8n import:workflow --input=/tmp/$name 2>&1 | grep -E 'Success|rror'"
      # import 하면 비활성화되므로, 원래 활성(active: true)인 워크플로우는 다시 publish
      if python3 -c "import json,sys; sys.exit(0 if json.load(open('$f')).get('active') else 1)"; then
        publish+=("$(python3 -c "import json; print(json.load(open('$f'))['id'])")")
      fi
    done
    for id in ${publish[@]+"${publish[@]}"}; do
      ssh "$HOST" "docker exec $CONTAINER n8n publish:workflow --id=$id 2>&1 | grep -E 'Publishing|rror'"
    done
    ssh "$HOST" "docker restart $CONTAINER >/dev/null && for i in \$(seq 1 24); do curl -sf -o /dev/null localhost:5678/healthz && echo 'n8n ready' && exit 0; sleep 5; done; echo 'n8n not ready' >&2; exit 1"
    ;;
  export)
    ssh "$HOST" "docker exec $CONTAINER n8n export:workflow --all --output=/tmp/all.json >/dev/null 2>&1 && docker exec $CONTAINER cat /tmp/all.json" \
      | KEYS=$KEYS python3 -c '
import glob, json, os, sys
ws = json.load(sys.stdin)
files = {json.load(open(f))["id"]: f for f in glob.glob("workflows/*.json")}
keep = ("id", "name", "active", "nodes", "connections", "settings")
for w in ws:
    for n in w["nodes"]:  # 받는 주소는 항상 __ALERT_TO__ (ALERT_TO 가 비어 GMAIL_ADDRESS 와 같아도)
        if n["type"] == "n8n-nodes-base.emailSend" and n["parameters"].get("toEmail") == os.environ["ALERT_TO"]:
            n["parameters"]["toEmail"] = "__ALERT_TO__"
    s = json.dumps({k: w[k] for k in keep if k in w}, ensure_ascii=False, indent=2)
    for k in ("SHEET_ID", "GMAIL_ADDRESS", "ALERT_TO"):
        s = s.replace(os.environ[k], "__" + k + "__") if os.environ[k] else s
    f = files.get(w["id"], "workflows/" + w["id"] + ".json")
    open(f, "w", encoding="utf-8").write(s + "\n")
    print("exported", f)
'
    ;;
  *)
    sed -n '2,9p' "$0"; exit 1
    ;;
esac

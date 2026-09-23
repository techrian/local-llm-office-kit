#!/usr/bin/env bash
# Open WebUI 백업 복원
#   사용법: sudo bash restore.sh /backup/open-webui/owui-2026-09-23-0300.tar.gz
set -euo pipefail
FILE="${1:-}"
[[ -f "$FILE" ]] || { echo "백업 파일 경로를 지정하세요"; ls -1t /backup/open-webui/*.tar.gz 2>/dev/null | head -5; exit 1; }
read -r -p "현재 데이터를 지우고 $FILE 로 복원합니다. 계속할까요? (yes 입력) " ans
[[ "$ans" == "yes" ]] || { echo "취소"; exit 1; }
DIR="$(dirname "$(readlink -f "$FILE")")"; NAME="$(basename "$FILE")"
docker stop open-webui
docker run --rm -v open-webui:/data -v "$DIR":/backup alpine \
  sh -c "rm -rf /data/* /data/.[!.]* 2>/dev/null; tar xzf /backup/$NAME -C /data"
docker start open-webui
echo "[OK] 복원 완료. 1분 뒤 접속해 확인하세요."

#!/usr/bin/env bash
# Open WebUI 데이터(계정·대화·지식·설정) 백업
#   사용법: sudo bash backup.sh [/backup/open-webui] [보관일수=14]
#   cron 등록(매일 03:00): sudo bash backup.sh --install-cron
set -euo pipefail
if [[ "${1:-}" == "--install-cron" ]]; then
  SELF="$(readlink -f "$0")"
  ( crontab -l 2>/dev/null | grep -v "$SELF"; echo "0 3 * * * /usr/bin/env bash $SELF >> /var/log/owui-backup.log 2>&1" ) | crontab -
  echo "[OK] 매일 03:00 백업 예약됨 (crontab -l 로 확인)"; exit 0
fi
DEST="${1:-/backup/open-webui}"; KEEP="${2:-14}"
mkdir -p "$DEST"
FILE="owui-$(date +%F-%H%M).tar.gz"
docker run --rm -v open-webui:/data:ro -v "$DEST":/backup alpine \
  tar czf "/backup/$FILE" -C /data .
find "$DEST" -name 'owui-*.tar.gz' -mtime +"$KEEP" -delete
echo "[OK] $(date '+%F %T') 백업 완료: $DEST/$FILE ($(du -h "$DEST/$FILE" | cut -f1))"
df -h "$DEST" | tail -1 | awk '{print "     백업 디스크 여유: "$4" ("$5" 사용)"}'

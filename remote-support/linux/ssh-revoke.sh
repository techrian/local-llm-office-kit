#!/usr/bin/env bash
# 임시 SSH 계정 즉시 회수 : 접속 강제 종료, 계정·권한·타이머 삭제
#   사용법: sudo bash ssh-revoke.sh
set -uo pipefail
USER_NAME="llm-support"
[[ $EUID -eq 0 ]] || { echo "sudo로 실행하세요"; exit 1; }
pkill -KILL -u "$USER_NAME" 2>/dev/null
sleep 1
userdel -r "$USER_NAME" 2>/dev/null && echo "[OK] 계정 삭제: $USER_NAME" || echo "[..] 계정 없음(이미 삭제됨)"
rm -f "/etc/sudoers.d/$USER_NAME"
# 자동 회수 타이머로 실행된 경우가 아니면 예약된 타이머 취소
if [[ -z "${INVOCATION_ID:-}" ]]; then
  systemctl stop llm-support-revoke.timer 2>/dev/null
fi
echo "$(date '+%F %T') 임시 계정 회수 완료" >> /var/log/llm-support.log
rm -f /usr/local/sbin/llm-support-revoke 2>/dev/null
echo "[OK] 원격 지원 권한이 모두 회수되었습니다."

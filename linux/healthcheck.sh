#!/usr/bin/env bash
# 주간 점검 스크립트 : GPU, 디스크, 서비스, 백업, 포트 노출 상태
#   사용법: bash healthcheck.sh
PASS=0; WARN=0
ok(){ echo -e "\e[32m[OK]\e[0m $*"; PASS=$((PASS+1)); }
ng(){ echo -e "\e[33m[!!]\e[0m $*"; WARN=$((WARN+1)); }

echo "== GPU =="
if command -v nvidia-smi >/dev/null; then
  nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader |
  while IFS=, read -r i n t u mu mt; do
    echo "  GPU$i$n | ${t// /}C | 사용률${u} | 메모리${mu} /${mt}"
    [[ ${t// /} -gt 85 ]] && echo "  -> 온도 높음! 먼지·팬 확인"
  done; ok "nvidia-smi 동작"
else ng "nvidia-smi 없음(드라이버 확인)"; fi

echo "== 서비스 =="
systemctl is-active --quiet ollama && ok "ollama 실행 중" || ng "ollama 중지됨: sudo systemctl start ollama"
curl -fsS -m 5 http://127.0.0.1:11434/api/tags >/dev/null && ok "Ollama API 응답" || ng "Ollama API 무응답"
for c in open-webui litellm vllm; do
  if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$c"; then
    [[ "$(docker inspect -f '{{.State.Running}}' "$c")" == "true" ]] && ok "컨테이너 $c 실행 중" || ng "컨테이너 $c 중지됨"
  fi
done
echo "  로드된 모델:"; ollama ps 2>/dev/null | sed 's/^/    /'
ollama ps 2>/dev/null | grep -q 'CPU' && ng "일부 모델이 CPU로 동작 중 (VRAM 부족 → 느림)"

echo "== 디스크 =="
df -h --output=target,size,avail,pcent / /backup 2>/dev/null | sed 's/^/  /'
USE=$(df --output=pcent / | tail -1 | tr -dc 0-9); [[ $USE -lt 80 ]] && ok "루트 디스크 ${USE}%" || ng "루트 디스크 ${USE}% (80% 이상)"

echo "== 백업 =="
LATEST=$(ls -1t /backup/open-webui/owui-*.tar.gz 2>/dev/null | head -1)
if [[ -n "$LATEST" ]] && [[ $(find "$LATEST" -mtime -2 | wc -l) -gt 0 ]]; then ok "최근 백업: $(basename "$LATEST")"
else ng "2일 이내 백업 없음 (backup.sh --install-cron)"; fi

echo "== 외부 노출 포트 =="
EXPOSED=$(ss -ltnH 2>/dev/null | awk '{print $4}' | grep -Ev '^(127\.0\.0\.1|\[::1\])' | sed 's/.*://' | sort -un | tr '\n' ' ')
echo "  외부 인터페이스에서 대기 중: ${EXPOSED}"
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q 'Status: active'; then ok "ufw 활성"; else ng "ufw 비활성 (firewall.sh 실행 권장)"; fi

echo; echo "결과: 정상 $PASS / 확인 필요 $WARN"

#!/usr/bin/env bash
# =============================================================================
# llama-server 실행 (전자책 11장 구성: 2개 GPU 텐서 분할, Q8, 256K 문맥, 내장 MTP)
# 모든 값은 환경 변수로 바꿀 수 있습니다. 예:
#   MODEL=~/llm/gguf/qwen3.8/Qwen3.8-27B-UD-Q8_K_XL.gguf GPUS=0,1 TS=23,28 bash run-server.sh
#   CTX=32768 MTP=0 bash run-server.sh          # 문제 생기면 짧은 문맥·MTP 끄고 최소 구성으로
#   SPLIT=layer bash run-server.sh              # 텐서 분할 문제 시 층 분할로
# =============================================================================
set -euo pipefail
BIN="${BIN:-$HOME/llm/llama.cpp/build/bin/llama-server}"
MODEL="${MODEL:?MODEL=<gguf 경로> 를 지정하세요}"
ALIAS="${ALIAS:-qwen3.8-27b}"
GPUS="${GPUS:-0,1}"          # 물리 GPU 번호 (nvidia-smi 기준)
TS="${TS:-23,28}"            # GPU별 분배 비율 (VRAM 용량 비에서 시작)
SPLIT="${SPLIT:-tensor}"     # tensor | layer
CTX="${CTX:-262144}"         # 256K
KV="${KV:-f16}"              # f16(품질) | q8_0(메모리 절약)
MTP="${MTP:-1}"              # 1: 모델 내장 MTP 사용
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
API_KEY="${API_KEY:-}"
MMPROJ="${MMPROJ:-}"         # 비전 입력용 mmproj 경로(선택)

[[ -x "$BIN" ]] || { echo "[XX] $BIN 없음 (build.sh 먼저 실행)"; exit 1; }
[[ -f "$MODEL" ]] || { echo "[XX] 모델 파일 없음: $MODEL"; exit 1; }
N=$(awk -F, '{print NF}' <<< "$GPUS"); DEVS=$(seq -s, -f 'CUDA%g' 0 $((N-1)))

ARGS=(--device "$DEVS" --split-mode "$SPLIT" -ngl all -ts "$TS"
      --host "$HOST" --port "$PORT" -m "$MODEL" --alias "$ALIAS"
      -c "$CTX" -b 2048 -ub 1024 -fa on -ctk "$KV" -ctv "$KV"
      -np 1 -t 8 -tb 16 --jinja --poll 0
      --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0
      --reasoning on --reasoning-effort xhigh --reasoning-format deepseek)
[[ "$SPLIT" == "tensor" ]] && ARGS+=(--fit off)
[[ "$MTP" == "1" ]] && ARGS+=(--spec-type draft-mtp --spec-draft-n-max 2)
[[ -n "$MMPROJ" ]] && ARGS+=(--mmproj "$MMPROJ")
if [[ -n "$API_KEY" ]]; then ARGS+=(--api-key "$API_KEY")
elif [[ "$HOST" != "127.0.0.1" ]]; then echo "[!!] 외부 대기($HOST)인데 API_KEY가 없습니다. API_KEY=... 를 지정하세요."; exit 1; fi

echo "[..] GPU $GPUS → $DEVS / split=$SPLIT ts=$TS / ctx=$CTX kv=$KV / MTP=$MTP"
export CUDA_VISIBLE_DEVICES="$GPUS" GGML_CUDA_BLOCKING_SYNC=1
exec "$BIN" "${ARGS[@]}"

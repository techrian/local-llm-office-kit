#!/usr/bin/env bash
# =============================================================================
# llama.cpp CUDA 빌드 (여러 세대 GPU 혼합 지원: 예 RTX 3090 sm_86 + V100 sm_70)
#   - 설치된 GPU의 compute capability를 자동 감지해 모두 포함
#   - NCCL(텐서 분할), Flash Attention, CUDA Graph 활성화
#
# 사용법:
#   bash build.sh                                  # ~/llm/llama.cpp 에 받아서 빌드
#   LLAMA_DIR=/opt/llama.cpp CUDA_HOME=/usr/local/cuda-12.8 bash build.sh
#   ARCHS="70-real;86-real" bash build.sh          # 아키텍처 직접 지정
# 필요 패키지: sudo apt install -y build-essential cmake git libnccl2 libnccl-dev
# =============================================================================
set -euo pipefail
LLAMA_DIR="${LLAMA_DIR:-$HOME/llm/llama.cpp}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.8}"
NVCC="$CUDA_HOME/bin/nvcc"

[[ -x "$NVCC" ]] || { echo "[XX] $NVCC 없음. CUDA_HOME을 지정하세요 (예: /usr/local/cuda-12.8)"; exit 1; }
echo "[..] $("$NVCC" --version | tail -1)"

if [[ -z "${ARCHS:-}" ]]; then
  CAPS=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | tr -d '.' | sort -u)
  ARCHS=$(for c in $CAPS; do printf '%s-real;' "$c"; done); ARCHS="${ARCHS%;}"
fi
echo "[..] 대상 GPU 아키텍처: $ARCHS"
nvidia-smi --query-gpu=index,name,compute_cap,memory.total --format=csv,noheader | sed 's/^/     /'
if echo "$ARCHS" | grep -q '^70\|;70'; then
  echo "[!!] Volta(V100, sm_70) 포함: CUDA 12.x 를 유지하세요 (CUDA 13은 Volta 지원 축소)"
fi

if [[ ! -d "$LLAMA_DIR/.git" ]]; then
  mkdir -p "$(dirname "$LLAMA_DIR")"
  git clone https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
else
  echo "[..] 기존 소스 사용: $LLAMA_DIR (최신으로: git -C $LLAMA_DIR pull)"
fi
cd "$LLAMA_DIR"
rm -rf build
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_COMPILER="$NVCC" \
  -DCMAKE_CUDA_ARCHITECTURES="$ARCHS" \
  -DGGML_CUDA=ON \
  -DGGML_CUDA_NCCL=ON \
  -DGGML_CUDA_FA=ON \
  -DGGML_CUDA_GRAPHS=ON \
  -DGGML_CUDA_COMPRESSION_MODE=speed
cmake --build build --config Release -j"$(nproc)" --target llama-server

echo
ldd build/bin/llama-server | grep -qi nccl && echo "[OK] NCCL 링크 확인" || echo "[!!] NCCL 미링크: libnccl-dev 설치 후 재빌드 (텐서 분할 성능 저하)"
echo "[OK] 빌드 완료: $LLAMA_DIR/build/bin/llama-server"
echo "     다음: bash run-server.sh  (환경 변수로 모델·GPU 지정)"

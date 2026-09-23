# 문제 해결

| 증상 | 원인 | 해결 |
|---|---|---|
| 응답이 매우 느림 (초당 몇 토큰) | 모델이 VRAM에 다 안 들어가 일부 CPU 처리 | `ollama ps` 확인 → 더 작은 모델 또는 4비트 양자화 |
| 첫 질문만 느림 | 모델 로딩 | `OLLAMA_KEEP_ALIVE=30m` 이상 |
| Open WebUI에 모델이 안 보임 (Linux) | 컨테이너 → Ollama 접속 실패 | `OLLAMA_HOST=0.0.0.0:11434` 인지, ufw에 `172.16.0.0/12 → 11434` 허용 규칙 있는지 |
| Open WebUI에 모델이 안 보임 (Windows Docker) | Ollama가 127.0.0.1에만 대기 | 사용자 환경 변수 `OLLAMA_HOST=0.0.0.0:11434` 후 Ollama 재시작, `.\firewall.ps1` |
| Windows에서 `open-webui` 명령을 못 찾음 | PATH 미반영 | 새 PowerShell 창 열기, 또는 `uv tool update-shell` 후 재로그인 |
| Windows에서 스크립트 실행 차단 | 실행 정책 | `Set-ExecutionPolicy -Scope Process Bypass -Force` |
| 한글이 깨져 보임 (Windows 콘솔) | 코드 페이지 | `chcp 65001`, Windows Terminal 사용 |
| 한국어 답변 중 중국어·영어 섞임 | 모델 특성·과도한 양자화 | 시스템 프롬프트에 "반드시 한국어로만" 추가, 모델 교체 |
| RAG가 문서 내용을 못 찾음 | 스캔 PDF, 표 깨짐 | OCR 후 업로드, 표를 "항목: 값" 텍스트로, 하이브리드 검색 켜기 |
| vLLM 메모리 부족(OOM) | 문맥·메모리 비율 과다 | `--max-model-len` 절반, `--gpu-memory-utilization 0.85` |
| 재부팅 후 웹 접속 불가 | 자동 시작 누락 | Linux: `--restart always` / Windows: 작업 스케줄러 `OpenWebUI` 확인 |
| GPU 오류·재부팅 | 과열·전원 | 먼지 청소, 파워 용량, `nvidia-smi -pl` 로 전력 제한 |

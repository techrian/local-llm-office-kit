# 명령어 모음 (Cheat Sheet)

## Ollama (Linux / Windows 공통)
| 목적 | 명령 |
|---|---|
| 모델 받기 | `ollama pull qwen3:32b` |
| 대화 | `ollama run qwen3:32b` (종료 `/bye`) |
| 받은 모델 목록 | `ollama list` |
| 메모리에 올라간 모델·GPU 비율 | `ollama ps` (PROCESSOR가 100% GPU여야 빠름) |
| 모델 삭제 | `ollama rm <모델>` |
| 모델 정보(문맥 길이 등) | `ollama show <모델>` |
| API 확인 | `curl http://127.0.0.1:11434/api/tags` |
| 버전 | `ollama --version` |

## Ollama 설정 위치
| | Linux | Windows |
|---|---|---|
| 설정 방법 | `sudo systemctl edit ollama` → `[Service]` `Environment="KEY=값"` | 시스템 속성 → 환경 변수(사용자) 또는 `setx KEY 값` 후 Ollama 재시작 |
| 로그 | `journalctl -u ollama -f` | `%LOCALAPPDATA%\Ollama\server.log` |
| 모델 저장 위치 | `/usr/share/ollama/.ollama/models` | `%USERPROFILE%\.ollama\models` |
| 재시작 | `sudo systemctl restart ollama` | 작업 표시줄 아이콘 → Quit 후 다시 실행 |

주요 환경 변수: `OLLAMA_HOST`(대기 주소), `OLLAMA_KEEP_ALIVE`(메모리 유지 시간), `OLLAMA_NUM_PARALLEL`(동시 처리 수), `OLLAMA_MODELS`(저장 위치), `OLLAMA_MAX_LOADED_MODELS`(동시에 올릴 모델 수)

## Docker / Open WebUI
| 목적 | 명령 |
|---|---|
| 컨테이너 상태 | `docker ps -a` |
| 로그 보기 | `docker logs -f --tail 100 open-webui` |
| 재시작 | `docker restart open-webui` |
| 포트 바인딩 확인 | `docker port open-webui` |
| 데이터 볼륨 위치 | `docker volume inspect open-webui` |
| 디스크 정리 | `docker image prune -f` |

## GPU
| 목적 | Linux | Windows |
|---|---|---|
| 상태 | `nvidia-smi` | `nvidia-smi` (PowerShell) |
| 실시간 | `watch -n1 nvidia-smi` / `nvtop` | `nvidia-smi -l 1` |
| 전력 제한(발열 대책) | `sudo nvidia-smi -pl 300` | 관리자 PowerShell에서 동일 |

## 네트워크·보안 점검
| 목적 | Linux | Windows |
|---|---|---|
| 열린 포트 | `ss -ltnp` | `Get-NetTCPConnection -State Listen` |
| 방화벽 | `sudo ufw status verbose` | `Get-NetFirewallRule -DisplayName "Ollama*","Open WebUI*"` |
| 다른 PC에서 포트 확인 | `nc -zv 서버IP 11434` (열려 있으면 안 됨) | `Test-NetConnection 서버IP -Port 11434` |

## 이 저장소의 스크립트
| 목적 | Linux | Windows |
|---|---|---|
| 설치 | `sudo bash linux/install.sh` | `.\windows\install.ps1` |
| 방화벽 | `sudo bash linux/firewall.sh 192.168.0.0/24` | `.\windows\firewall.ps1` |
| HTTPS | `sudo bash linux/caddy-setup.sh ai.company.local` | (Windows 서버는 사내 PC 5~10명 시범용 권장) |
| 백업 | `sudo bash linux/backup.sh --install-cron` | `.\windows\backup.ps1 -InstallTask` |
| 업데이트 | `sudo bash linux/update.sh` | `.\windows\update.ps1` |
| 점검 | `bash linux/healthcheck.sh` | `.\windows\healthcheck.ps1` |

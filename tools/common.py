"""공통 설정: 환경 변수로 서버 주소·키·모델을 바꿉니다.

  LLM_BASE_URL  기본 http://127.0.0.1:11434/v1  (Ollama)
                LiteLLM: http://127.0.0.1:4000/v1 / vLLM: http://127.0.0.1:8000/v1
  LLM_API_KEY   기본 "ollama" (Ollama는 검사하지 않음)
  LLM_MODEL     기본 qwen3:32b
"""
import os
from openai import OpenAI, AsyncOpenAI

BASE_URL = os.getenv("LLM_BASE_URL", "http://127.0.0.1:11434/v1")
API_KEY = os.getenv("LLM_API_KEY", "ollama")
MODEL = os.getenv("LLM_MODEL", "qwen3:32b")


def client() -> OpenAI:
    return OpenAI(base_url=BASE_URL, api_key=API_KEY, timeout=600)


def aclient() -> AsyncOpenAI:
    return AsyncOpenAI(base_url=BASE_URL, api_key=API_KEY, timeout=600)

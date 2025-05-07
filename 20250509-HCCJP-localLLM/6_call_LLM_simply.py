"""
超シンプルな /chat/completions サンプル

- OpenAI 公式エンドポイントとローカル (LM Studio) エンドポイントを
  コメント操作だけで切り替え
- API キーは .env から取得
"""
from __future__ import annotations

import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()  # .env 内の OPENAI_API_KEY 等を読み込む

# ===== エンドポイント切り替え（コメント操作） =====================
# --- OpenAI ---------------------------------------------------------
#base_url = None
#api_key  = os.getenv("OPENAI_API_KEY")
#model    = "gpt-4.1"

# --- Local (LM Studio) ---------------------------------------------
base_url = "http://localhost:1234/v1"
api_key  = "lm-studio"        # LM Studio では任意の文字列で可
model    = "qwen3-4b"
# ================================================================

client_kwargs = {}
if base_url:
    client_kwargs["base_url"] = base_url
if api_key:
    client_kwargs["api_key"] = api_key

client = OpenAI(**client_kwargs)  # type: ignore[arg-type]

messages = [{"role": "user", "content": "こんにちは！"}]

response = client.chat.completions.create(
    model=model,
    messages=messages,
    temperature=0.7,
)

print(response.choices[0].message.content)

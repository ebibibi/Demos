from langchain_openai import ChatOpenAI
from langchain_openai import ChatOpenAI as LocalOpenAI
from dotenv import load_dotenv
import os

load_dotenv()
openai_api_key = os.getenv("OPENAI_API_KEY")

local_model = LocalOpenAI(
    model="qwen3-4b",
    base_url="http://127.0.0.1:1234/v1",
    api_key="local-api-key"  # ダミーの値
)
openai_model = ChatOpenAI(
    model="gpt-4.1",
    api_key=openai_api_key
)

model = local_model.with_fallbacks([openai_model]) # ローカルモデルを優先し、失敗した場合はOpenAI APIを使用
result = model.invoke('こんにちは！')
print(result.content)
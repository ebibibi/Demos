from openai import OpenAI
from dotenv import load_dotenv
import os

load_dotenv()  # .env 内の OPENAI_API_KEY 等を読み込む
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

client = OpenAI(
  base_url="https://openrouter.ai/api/v1",
  api_key=OPENROUTER_API_KEY,
)

completion = client.chat.completions.create(
  model="microsoft/phi-4-reasoning:free",
  messages=[
    {
      "role": "user",
      "content": "こんにちは！"
    }
  ]
)
print("microsoft/phi-4-reasoning:free")
print(completion.choices[0].message.content)

print("==========================")

completion = client.chat.completions.create(
  model="qwen/qwen3-0.6b-04-28:free",
  messages=[
    {
      "role": "user",
      "content": "こんにちは！"
    }
  ]
)

print("qwen/qwen3-0.6b-04-28:free")
print(completion.choices[0].message.content)
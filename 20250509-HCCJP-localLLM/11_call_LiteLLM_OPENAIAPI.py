import openai
client = openai.OpenAI(
    api_key="sk-f7UK9l5-tg8zQ6znOTWMhQ",
    base_url="http://localhost:4000" # LiteLLM Proxy is OpenAI compatible, Read More: https://docs.litellm.ai/docs/proxy/user_keys
)

response = client.chat.completions.create(
    model="openai/qwen3-4b", # model to send to the proxy
    messages = [
        {
            "role": "user",
            "content": "こんにちは！元気ですか？"
        }
    ]
)

print("qwen3-4b")
print(response.choices[0].message.content)
print("==========================")

response = client.chat.completions.create(
    model="gpt-4.1", # model to send to the proxy
    messages = [
        {
            "role": "user",
            "content": "こんにちは！元気ですか？"
        }
    ]
)

print("gpt-4.1")
print(response.choices[0].message.content)


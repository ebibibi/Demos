curl http://localhost:1234/v1/models

curl -X POST http://localhost:1234/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model": "Qwen/Qwen3-1.7b",
  "messages": [
    {
      "role": "user",
      "content": "こんにちは！"
    }
  ],
  "temperature": 0.7,
  "max_tokens": 100
}'

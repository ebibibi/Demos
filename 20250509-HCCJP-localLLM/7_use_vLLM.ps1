docker run --gpus all -v ~/.cache/huggingface:/root/.cache/huggingface -p 8000:8000 --ipc=host  vllm/vllm-openai:latest --trust-remote-code --model Qwen/Qwen3-1.7b --dtype half --max-model-len 4096

curl http://localhost:8000/v1/models
curl -X POST http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" -d '{
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

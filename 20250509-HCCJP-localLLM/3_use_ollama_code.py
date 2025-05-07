import ollama
response = ollama.chat(model='gemma3', messages=[
  {
    'role': 'user',
    'content': 'こんにちは！',
  },
])
print(response['message']['content'])
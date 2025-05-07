import torch

from transformers import AutoModelForCausalLM, AutoTokenizer

model_name = "Qwen/Qwen3-1.7B"

# decide device (CUDA-first, CPU fallback)
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# load the tokenizer and the model on that device (FP16)
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype=torch.float16,    # FP16 keeps memory small & is fast on CUDA
).to(device)

# prepare the model input
prompt = "こんにちは！"
messages = [
    {"role": "user", "content": prompt}
]
text = tokenizer.apply_chat_template(
    messages,
    tokenize=False,
    add_generation_prompt=True,
    enable_thinking=True # Switches between thinking and non-thinking modes. Default is True.
)
model_inputs = tokenizer([text], return_tensors="pt")
model_inputs = {k: v.to(device) for k, v in model_inputs.items()}

# conduct text completion (keep it reasonable for GPU memory)
with torch.no_grad():
    generated_ids = model.generate(
        **model_inputs,
        max_new_tokens=1024       # smaller than 32 768 – avoid OOM / long wait
    )

# NEW ↓ – get prompt length from the dict
input_len = model_inputs["input_ids"].shape[-1]
output_ids = generated_ids[0][input_len:].tolist()

# parsing thinking content
try:
    # rindex finding 151668 (</think>)
    index = len(output_ids) - output_ids[::-1].index(151668)
except ValueError:
    index = 0

thinking_content = tokenizer.decode(output_ids[:index], skip_special_tokens=True).strip("\n")
content = tokenizer.decode(output_ids[index:], skip_special_tokens=True).strip("\n")

print("thinking content:", thinking_content)
print("content:", content)
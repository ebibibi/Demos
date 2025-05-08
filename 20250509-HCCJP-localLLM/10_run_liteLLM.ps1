cd C:\repos\litellm

$env:LITELLM_MASTER_KEY="sk-1234"
$env:LITELLM_SALT_KEY="sk-1234"

docker-compose up

Start-Process http://localhost:4000/ui/
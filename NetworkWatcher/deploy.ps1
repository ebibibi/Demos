# RG作成
az group create -n rg-nw-demo -l japaneast

# デプロイ
az deployment group create -g rg-nw-demo -f main.bicep -p sshPublicKey="$(cat ~/.ssh/id_rsa.pub)" prefix="nw-demo" location="japaneast"

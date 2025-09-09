# Windows 11 VM Deployment
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "HCCJP_64_Demo_VM",
    
    [Parameter(Mandatory = $false)]
    [string]$VmName = "hccjpdemo"
)

$ErrorActionPreference = "Stop"

Write-Host "Windows 11 VM Deployment" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

# Azure CLI ログイン確認
try {
    $account = az account show --query "name" --output tsv 2>$null
    if (-not $account) {
        throw "Not logged in"
    }
    $tenantId = az account show --query "tenantId" --output tsv
    Write-Host "現在のサブスクリプション: $account" -ForegroundColor Green
    Write-Host "参加先Entra IDテナント: $tenantId" -ForegroundColor Cyan
}
catch {
    Write-Host "Azure CLI にログインしてください..." -ForegroundColor Red
    az login
}

# パスワード入力
$SecurePassword = Read-Host -Prompt "管理者パスワードを入力してください" -AsSecureString
$AdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))

# リソースグループ作成
$rgExists = az group exists --name $ResourceGroup --output tsv
if ($rgExists -eq "false") {
    Write-Host "リソースグループ作成中..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location "Japan East"
}

try {
    Write-Host "VM展開中..." -ForegroundColor Yellow
    
    $deploymentResult = az deployment group create `
        --resource-group $ResourceGroup `
        --template-file "main.bicep" `
        --parameters vmName="$VmName" adminPassword="$AdminPassword" `
        --output json | ConvertFrom-Json
        
    if ($deploymentResult.properties.provisioningState -eq "Succeeded") {
        Write-Host "展開完了！" -ForegroundColor Green
        
        # 接続情報表示
        $vmInfo = az vm show --resource-group $ResourceGroup --name $VmName --show-details --query "{publicIp:publicIps,fqdn:fqdns}" -o json | ConvertFrom-Json
        
        Write-Host "`n=== 接続情報 ===" -ForegroundColor Cyan
        Write-Host "VM名: $VmName" -ForegroundColor White
        Write-Host "パブリックIP: $($vmInfo.publicIp)" -ForegroundColor White
        Write-Host "FQDN: $($vmInfo.fqdn)" -ForegroundColor White
        
        Write-Host "`n=== 実行された設定 ===" -ForegroundColor Cyan
        Write-Host "✓ Cloud Kerberos Ticket有効化" -ForegroundColor Green
        Write-Host "✓ PowerShell実行ポリシー設定" -ForegroundColor Green
        Write-Host "✓ Entra ID自動参加" -ForegroundColor Green
        
        Write-Host "`n=== 次のステップ ===" -ForegroundColor Cyan
        Write-Host "1. Entra ID参加完了まで5-10分待機" -ForegroundColor Yellow
        Write-Host "2. ロール割り当て:" -ForegroundColor Yellow
        $vmResourceId = az vm show --resource-group $ResourceGroup --name $VmName --query "id" -o tsv
        Write-Host "   az role assignment create --assignee <user@domain.com> --role 'Virtual Machine User Login' --scope '$vmResourceId'" -ForegroundColor Gray
    }
    else {
        throw "展開失敗: $($deploymentResult.properties.provisioningState)"
    }
}
catch {
    Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
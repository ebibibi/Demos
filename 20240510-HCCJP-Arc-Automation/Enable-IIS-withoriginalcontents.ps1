# 参考
# https://learn.microsoft.com/ja-jp/azure/governance/machine-configuration/how-to/develop-custom-package/1-set-up-authoring-environment
# https://cloudbrothers.info/azure-persistence-azure-policy-guest-configuration/


#PowerShell 7で実行

Install-Module -Name 'GuestConfiguration','PSDscResources'
Install-Module -Name 'PSDesiredStateConfiguration' -AllowPrerelease


# ConfigurationはPSDscResourcesしか使えない。PSDesiredStateConfigurationは使えない。
# 現時点ではほとんどのものが使えないので注意。
Configuration EnableIIS {
    param()

    Import-DscResource -ModuleName 'PSDscResources'

    Node "localhost" {
        Script InstallWebServer {
            GetScript = {
                $featureState = Get-WindowsFeature -Name "Web-Server"
                return @{
                    Result = $featureState.InstallState -eq "Installed"
                }
            }
            TestScript = {
                $featureState = Get-WindowsFeature -Name "Web-Server"
                return $featureState.InstallState -eq "Installed"
            }
            SetScript = {
                Install-WindowsFeature -Name "Web-Server"
            }
        }

        Script DeployWebsiteContent1 {
            GetScript = {
                $exists = Test-Path "c:\inetpub\wwwroot\index.htm"
                $content = $null
                if ($exists) {
                    $content = Get-Content "c:\inetpub\wwwroot\index.htm" -Raw
                }
                return @{
                    Result = $content
                }
            }
            TestScript = {
                Test-Path "c:\inetpub\wwwroot\index.htm"
            }
            SetScript = {
                $url = "https://raw.githubusercontent.com/ebibibi/Demos/main/20240510-HCCJP-Arc-Automation/webcontents/index.htm"
                $output = "C:\inetpub\wwwroot\index.htm"
                Invoke-WebRequest -Uri $url -OutFile $output
            }
            DependsOn = "[Script]InstallWebServer"
        }

        Script DeployWebsiteContent2 {
            GetScript = {
                $exists = Test-Path "c:\inetpub\wwwroot\logo.png"
                $content = $null
                if ($exists) {
                    $content = Get-Content "c:\inetpub\wwwroot\logo.png" -Raw
                }
                return @{
                    Result = $content
                }
            }
            TestScript = {
                Test-Path "c:\inetpub\wwwroot\logo.png"
            }
            SetScript = {
                $url = "https://raw.githubusercontent.com/ebibibi/Demos/main/20240510-HCCJP-Arc-Automation/webcontents/logo.png"
                $output = "C:\inetpub\wwwroot\logo.png"
                Invoke-WebRequest -Uri $url -OutFile $output
            }
            DependsOn = "[Script]InstallWebServer"
        }
    }
}

EnableIIS

# localhost.mofをリネームする
Move-Item '.\EnableIIS\localhost.mof' '.\EnableIIS\EnableIIS.mof' -Force


# ゲスト構成パッケージを作成する
New-GuestConfigurationPackage `
  -Name 'EnableIIS' `
  -Configuration './EnableIIS/EnableIIS.mof' `
  -Type AuditAndSet  `
  -Path './EnableIIS' `
  -Force

# 基本要件のテスト
Get-GuestConfigurationPackageComplianceStatus -Path .\EnableIIS\EnableIIS.zip

# 構成適用テスト
Start-GuestConfigurationPackageRemediation -Path .\EnableIIS\EnableIIS.zip
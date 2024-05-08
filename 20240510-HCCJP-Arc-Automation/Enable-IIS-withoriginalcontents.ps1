https://learn.microsoft.com/ja-jp/azure/governance/machine-configuration/how-to/develop-custom-package/1-set-up-authoring-environment

https://cloudbrothers.info/azure-persistence-azure-policy-guest-configuration/


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
                Copy-Item "\\arc-iisdemo-wac\webcontents\index.htm" "c:\inetpub\wwwroot\index.htm"
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
                Copy-Item "\\arc-iisdemo-wac\webcontents\logo.png" "c:\inetpub\wwwroot\logo.png"
            }
            DependsOn = "[Script]InstallWebServer"
        }
    }
}

EnableIIS

# localhost.mofをリネームする
Rename-Item -Path '.\EnableIIS\localhost.mof' -NewName 'EnableIIS.mof'


# ゲスト構成パッケージを作成する
New-GuestConfigurationPackage `
  -Name 'EnableIIS' `
  -Configuration './EnableIIS/EnableIIS.mof' `
  -Type AuditAndSet  `
  -Force

# 基本要件のテスト
Get-GuestConfigurationPackageComplianceStatus -Path .\EnableIIS.zip

# 構成適用テスト
Start-GuestConfigurationPackageRemediation -Path .\EnableIIS.zip
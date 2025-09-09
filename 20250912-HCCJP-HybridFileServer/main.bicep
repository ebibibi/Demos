@description('管理者ユーザー名')
param adminUsername string = 'mebisuda'

@description('管理者パスワード')
@secure()
param adminPassword string

@description('仮想マシン名')
param vmName string = 'win11'

@description('VMサイズ')
param vmSize string = 'Standard_D2s_v3'

@description('リソースグループの場所')
param location string = resourceGroup().location

@description('仮想ネットワーク名')
param vnetName string = 'vnet-${uniqueString(resourceGroup().id)}'

@description('サブネット名')
param subnetName string = 'default'

@description('ネットワークセキュリティグループ名')
param nsgName string = 'nsg-${vmName}'

@description('パブリックIP名')
param publicIpName string = 'pip-${vmName}'

@description('Entra ID への自動参加を有効にするかどうか')
param enableEntraJoin bool = true

// 仮想ネットワークとサブネット
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

// ネットワークセキュリティグループ
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'AllowEntraIDEndpoints'
        properties: {
          priority: 1100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// パブリックIP
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${vmName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// ネットワークインターフェース
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-${vmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

// 仮想マシン
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: 'win11-23h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    licenseType: 'Windows_Client'
  }
}

// Custom Script Extension - インラインコマンド実行
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "Write-Host \'VM初期設定開始\'; try { reg add HKLM\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters /v CloudKerberosTicketRetrievalEnabled /t REG_DWORD /d 1 /f; Write-Host \'Cloud Kerberos設定完了\' } catch { Write-Host \'エラー: $_\' }; try { Set-ExecutionPolicy RemoteSigned -Force; Write-Host \'PowerShell実行ポリシー設定完了\' } catch { Write-Host \'実行ポリシー設定エラー: $_\' }; Write-Host \'初期設定完了\'"'
    }
  }
}

// Entra ID Join 拡張機能
resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (enableEntraJoin) {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: ''
    }
  }
  dependsOn: [
    customScriptExtension
  ]
}

// 出力
output vmName string = virtualMachine.name
output adminUsername string = adminUsername
output hostname string = publicIP.properties.dnsSettings.domainNameLabel
output publicIPAddress string = publicIP.properties.ipAddress
output resourceGroupName string = resourceGroup().name
output vmResourceId string = virtualMachine.id
@description('Deployment location')
param location string = resourceGroup().location

@description('Name prefix for all resources')
param prefix string = 'nw-demo'

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for Linux VMs')
param sshPublicKey string

@description('VM size')
param vmSize string = 'Standard_B2s'

var vnetName = '${prefix}-vnet'
var clientSubnetName = 'sn-client'
var serverSubnetName = 'sn-server'
var clientNsgName = '${prefix}-nsg-client'
var serverNsgName = '${prefix}-nsg-server'
var nwName = 'NetworkWatcher_${location}'

// ---------------- Network Watcher ----------------
resource nw 'Microsoft.Network/networkWatchers@2024-07-01' = {
  name: nwName
  location: location
}

// ---------------- Storage (for Flow Logs) ----------------
// Storage account to store Network Watcher flow logs
var flowLogSaNameRaw = '${replace(prefix, '-', '')}${uniqueString(resourceGroup().id)}fl'
var flowLogSaName = toLower(substring(flowLogSaNameRaw, 0, min(length(flowLogSaNameRaw), 24)))

resource flowLogStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: flowLogSaName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ---------------- VNet & Subnets ----------------
resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.10.0.0/16' ] }
    subnets: [
      {
        name: clientSubnetName
        properties: {
          addressPrefix: '10.10.1.0/24'
          natGateway: {
            id: natGw.id
          }
        }
      }
      {
        name: serverSubnetName
        properties: {
          addressPrefix: '10.10.2.0/24'
          natGateway: {
            id: natGw.id
          }
        }
      }
    ]
  }
}

// ---------------- NSGs ----------------
resource clientNsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: clientNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource serverNsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: serverNsgName
  location: location
  properties: {
    securityRules: [
      // デモ用：clientサブネット→serverの80/TCPを遮断
      {
        name: 'Deny-HTTP-From-ClientSubnet'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.1.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      // VNet内の80/TCPは許可（優先度を下げる）
      {
        name: 'Allow-HTTP-From-VNet'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      // インターネットからのHTTP(80/TCP)を許可
      {
        name: 'Allow-HTTP-Internet'
        properties: {
          priority: 350
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      // SSH（操作用）
      {
        name: 'Allow-SSH-Internet'
        properties: {
          priority: 400
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// ---------------- Public IPs ----------------
// Client public IP
resource clientPip 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: '${prefix}-pip-client-std'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Server public IP
resource serverPip 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: '${prefix}-pip-server-std'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ---------------- NAT Gateway (egress for subnets) ----------------
resource natPip 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: '${prefix}-pip-nat'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGw 'Microsoft.Network/natGateways@2024-07-01' = {
  name: '${prefix}-natgw'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIpAddresses: [
      {
        id: natPip.id
      }
    ]
  }
}

// ---------------- NICs ----------------
resource nicClient 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: '${prefix}-nic-client'
  location: location
  // Ensure VNet and its subnets exist before NIC creation
  dependsOn: [ vnet ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, clientSubnetName) }
          publicIPAddress: { id: clientPip.id }
        }
      }
    ]
    networkSecurityGroup: { id: clientNsg.id }
  }
}

resource nicServer 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: '${prefix}-nic-server'
  location: location
  // Ensure VNet and its subnets exist before NIC creation
  dependsOn: [ vnet ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, serverSubnetName) }
          publicIPAddress: { id: serverPip.id }
        }
      }
    ]
    networkSecurityGroup: { id: serverNsg.id }
  }
}

// ---------------- VMs (Ubuntu 22.04 LTS Gen2) ----------------
resource vmClient 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${prefix}-vm-client'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: '${prefix}-vm-client'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [ { id: nicClient.id } ] }
  }
}

resource vmServer 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${prefix}-vm-server'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: '${prefix}-vm-server'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [ { id: nicServer.id } ] }
  }
}

// ---------------- Install Nginx on server (Custom Script for Linux) ----------------
resource installNginx 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  name: 'install-nginx'
  location: location
  parent: vmServer
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'bash -c "apt-get update && apt-get install -y nginx && systemctl enable --now nginx"'
    }
  }
}

// ---------------- Action Group (Email) ----------------
// Azure Monitor Action Group to send email notifications
resource agEmail 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${prefix}-ag-email'
  location: 'Global'
  properties: {
    groupShortName: 'nwalert'
    enabled: true
    emailReceivers: [
      {
        name: 'PrimaryEmail'
        emailAddress: 'ebibibi@gmail.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

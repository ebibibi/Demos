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

@description('Install VM extensions and runCommand (may fail without outbound). Default off.')
param enableVmExtensions bool = false

var vnetName = '${prefix}-vnet'
var clientSubnetName = 'sn-client'
var serverSubnetName = 'sn-server'
var clientNsgName = '${prefix}-nsg-client'
var serverNsgName = '${prefix}-nsg-server'
var laName = '${prefix}-law'
var nwName = 'NetworkWatcher_${location}'

// ---------------- Network Watcher ----------------
resource nw 'Microsoft.Network/networkWatchers@2024-07-01' = {
  name: nwName
  location: location
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

// ---------------- Public IP (clientのみ) ----------------
resource clientPip 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: '${prefix}-pip-client'
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
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, serverSubnetName) }
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
      // Install nginx via cloud-init instead of runCommand
      customData: base64('#cloud-config\npackages:\n  - nginx\nruncmd:\n  - systemctl enable --now nginx\n')
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

// ---------------- Install Nginx on server (runCommand) ----------------
// Optional: runCommand to install nginx (disabled by default)
resource installNginx 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = if (enableVmExtensions) {
  name: 'install-nginx'
  location: location
  parent: vmServer
  properties: {
    source: { script: 'sudo apt-get update && sudo apt-get install -y nginx && sudo systemctl enable --now nginx' }
    asyncExecution: false
  }
}

// ---------------- Network Watcher Agent (VM extensions) ----------------
resource nwExtClient 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if (enableVmExtensions) {
  name: 'AzureNetworkWatcherExtension'
  location: location
  parent: vmClient
  properties: {
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentLinux'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
  }
}

resource nwExtServer 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if (enableVmExtensions) {
  name: 'AzureNetworkWatcherExtension'
  location: location
  parent: vmServer
  properties: {
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentLinux'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {}
  }
}

// ---------------- Log Analytics Workspace ----------------
resource law 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: laName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ---------------- Connection Monitor (vm-client -> vm-server: TCP/80) ----------------
resource connMon 'Microsoft.Network/networkWatchers/connectionMonitors@2024-07-01' = {
  name: '${prefix}-cm'
  location: location
  parent: nw
  properties: {
    autoStart: true
    endpoints: [
      { name: 'src', resourceId: vmClient.id }
      { name: 'dst', resourceId: vmServer.id }
    ]
    testConfigurations: [
      {
        name: 'tcp80'
        protocol: 'Tcp'
        tcpConfiguration: { port: 80 }
        testFrequencySec: 30
      }
    ]
    testGroups: [
      {
        name: 'tg1'
        sources: [ 'src' ]
        destinations: [ 'dst' ]
        testConfigurations: [ 'tcp80' ]
      }
    ]
    outputs: [
      { type: 'Workspace', workspaceSettings: { workspaceResourceId: law.id } }
    ]
  }
}

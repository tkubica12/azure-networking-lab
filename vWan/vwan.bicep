var location = resourceGroup().location

// Virtual WAN
resource vWan 'Microsoft.Network/virtualWans@2020-11-01' = {
  name: 'my-vwan'
  location: 'westeurope'
  properties: {
    type: 'Standard'
    allowBranchToBranchTraffic: true
    allowVnetToVnetTraffic: true
  }
}

resource weHub 'Microsoft.Network/virtualHubs@2020-11-01' = {
  name: 'we-hub'
  location: 'westeurope'
  properties: {
    addressPrefix: '10.0.0.0/24'
    sku: 'Standard'
    virtualWan: {
      id: vWan.id
    }
  }
}

resource weVpn 'Microsoft.Network/vpnGateways@2020-11-01' = {
  name: 'we-vpn'
  location: 'westeurope'
  properties: {
    vpnGatewayScaleUnit: 1
    virtualHub: {
      id: weHub.id
    }
  }
}

resource neHub 'Microsoft.Network/virtualHubs@2020-11-01' = {
  name: 'ne-hub'
  location: 'northeurope'
  properties: {
    addressPrefix: '10.1.0.0/24'
    sku: 'Standard'
    virtualWan: {
      id: vWan.id
    }
  }
}

resource neVpn 'Microsoft.Network/vpnGateways@2020-11-01' = {
  name: 'ne-vpn'
  location: 'northeurope'
  properties: {
    vpnGatewayScaleUnit: 1
    virtualHub: {
      id: neHub.id
    }
  }
}

resource weRouteTableToFirewall 'Microsoft.Network/virtualHubs/hubRouteTables@2020-11-01' = {
  name: 'AllToFirewallWe'
  parent: weHub
  properties: {
    routes: [
      {
        name: 'AllToFirewallWe'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHopType: 'ResourceId'
        nextHop: fwWe.id
      }
    ]
  }
}

resource weRouteTableInternalToFirewall 'Microsoft.Network/virtualHubs/hubRouteTables@2020-11-01' = {
  name: 'InternalToFirewallWe'
  parent: weHub
  properties: {
    routes: [
      {
        name: 'InternalToFirewallWe'
        destinationType: 'CIDR'
        destinations: [
          '10.0.0.0/8'
        ]
        nextHopType: 'ResourceId'
        nextHop: fwWe.id
      }
    ]
  }
}

resource neRouteTableToFirewall 'Microsoft.Network/virtualHubs/hubRouteTables@2020-11-01' = {
  name: 'AllToFirewallNe'
  parent: neHub
  properties: {
    routes: [
      {
        name: 'AllToFirewallNe'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHopType: 'ResourceId'
        nextHop: fwNe.id
      }
    ]
  }
}

// Networks
resource weJump 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'we-jump-net'
  location: 'westeurope'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.99.0/24'
      ]
    }
    subnets: [
      {
        name: 'jump'
        properties: {
          addressPrefix: '10.0.99.0/25'
        } 
      }
    ]
  }
}

resource weJumpConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'we-jump-connection'
  parent: weHub
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: weJump.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: weRouteTableInternalToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: weRouteTableInternalToFirewall.id
          }
        ]
      }
    }
  }
}

resource weSpoke1 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'we-spoke1-net'
  location: 'westeurope'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.1.0/24'
      ]
    }
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix: '10.0.1.0/25'
        } 
      }
    ]
  }
}

resource weSpoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'we-spoke1-connection'
  parent: weHub
  dependsOn: [
    weJumpConnection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: weSpoke1.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: weRouteTableToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: weRouteTableToFirewall.id
          }
        ]
      }
    }
  }
}

resource weSpoke2 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'we-spoke2-net'
  location: 'westeurope'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.2.0/24'
      ]
    }
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix: '10.0.2.0/25'
        } 
      }
    ]
  }
}

resource weSpoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'we-spoke2-connection'
  parent: weHub
  dependsOn: [
    weJumpConnection
    weSpoke1Connection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: weSpoke2.id
    }
    // routingConfiguration: {
    //   associatedRouteTable: {
    //     id: weRouteTableToFirewall.id
    //   }
    //   propagatedRouteTables: {
    //     ids: [
    //       {
    //         id: weRouteTableToFirewall.id
    //       }
    //     ]
    //   }
    // }
  }
}

resource neSpoke1 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'ne-spoke1-net'
  location: 'northeurope'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.1.0/24'
      ]
    }
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix: '10.1.1.0/25'
        } 
      }
    ]
  }
}

resource neSpoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'ne-spoke1-connection'
  parent: neHub
  dependsOn: [
    weJumpConnection
    weSpoke1Connection
    weSpoke2Connection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: neSpoke1.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: neRouteTableToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: neRouteTableToFirewall.id
          }
        ]
      }
    }
  }
}

resource neSpoke2 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'ne-spoke2-net'
  location: 'westeurope'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.2.0/24'
      ]
    }
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix: '10.1.2.0/25'
        } 
      }
    ]
  }
}

resource neSpoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'ne-spoke2-connection'
  parent: neHub
  dependsOn: [
    weJumpConnection
    weSpoke1Connection
    weSpoke2Connection
    neSpoke1Connection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: neSpoke2.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: neRouteTableToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: neRouteTableToFirewall.id
          }
        ]
      }
    }
  }
}

// Azure Firewall
resource fwPolicy 'Microsoft.Network/firewallPolicies@2020-11-01' = {
  name: 'fw-policy'
  location: 'westeurope'
  properties: {
    threatIntelMode: 'Deny'
    sku: {
      tier: 'Standard'
    }
  }
}

resource fwRulesApp 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  name: 'DefaultApplicationRuleCollectionGroup'
  parent: fwPolicy
  dependsOn: [
    fwRulesNet
  ]
  properties: {
    priority: 300
    ruleCollections: [
      {
        name: 'allowMicrosoft'
        priority: 100
        action: {
          type: 'Allow'
        }
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'MicrosoftUpdate'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: [
              '*'
            ]
            fqdnTags: [
              'WindowsUpdate'
            ]
            terminateTLS: false
          }
        ]
      }
    ]
  }
}

resource fwRulesNet 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  name: 'DefaultNetworkRuleCollectionGroup'
  parent: fwPolicy
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        priority: 200
        rules: [
          {
            name: 'allowIcmp'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'ICMP'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
          }
          {
            name: 'allowSsh'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.99.0/24'
            ]
            destinationAddresses: [
              '10.0.0.0/8'
            ]
            destinationPorts: [
              '22'
            ]
          }
        ]
      }
    ]
  }
}

resource fwWe 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: 'fw-we'
  location: 'westeurope'
  dependsOn: [
    fwRulesApp
    fwRulesNet
  ]
  properties: {
    firewallPolicy: {
      id: fwPolicy.id
    }
    sku: {
      name: 'AZFW_Hub'
      tier: 'Standard'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    virtualHub: {
      id: weHub.id
    }
  } 
}

resource fwNe 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: 'fw-ne'
  location: 'northeurope'
  dependsOn: [
    fwRulesApp
    fwRulesNet
  ]
  properties: {
    firewallPolicy: {
      id: fwPolicy.id
    }
    sku: {
      name: 'AZFW_Hub'
      tier: 'Standard'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    virtualHub: {
      id: neHub.id
    }
  } 
}

// Virtual Machines
var size = 'Standard_B1ms'
var username = 'tomas'
var password = 'Azure12345678'

resource ipJump 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'jumpserver-ip'
  location: 'westeurope'
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nicJump 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'jumpserver-nic'
  location: 'westeurope'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.99.4'
          publicIPAddress: {
            id: ipJump.id
          }
          subnet: {
            id: '${weJump.id}/subnets/jump'
          }
        }
      }
    ]
  }
}
resource vmJump 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'jumpserver-vm'
  location: 'westeurope'
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'jumpserver-vm'
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicJump.id
        }
      ]
    }
  }
}


resource nic1 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'we-spoke1-nic'
  location: 'westeurope'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.4'
          subnet: {
            id: '${weSpoke1.id}/subnets/sub1'
          }
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'we-spoke1-vm'
  location: 'westeurope'
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'we-spoke1-vm'
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic1.id
        }
      ]
    }
  }
}

resource nic2 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'ne-spoke1-nic'
  location: 'northeurope'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.1.1.4'
          subnet: {
            id: '${neSpoke1.id}/subnets/sub1'
          }
        }
      }
    ]
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'ne-spoke1-vm'
  location: 'northeurope'
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'ne-spoke1-vm-vm'
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic2.id
        }
      ]
    }
  }
}

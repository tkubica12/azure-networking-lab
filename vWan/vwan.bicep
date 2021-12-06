var location = resourceGroup().location

// Virtual WAN
resource vWan 'Microsoft.Network/virtualWans@2020-11-01' = {
  name: 'my-vwan'
  location: 'CentralUS'
  properties: {
    type: 'Standard'
    allowBranchToBranchTraffic: true
    allowVnetToVnetTraffic: true
  }
}

resource CNUSHub 'Microsoft.Network/virtualHubs@2020-11-01' = {
  name: 'CNUS-hub'
  location: 'CentralUS'
  properties: {
    addressPrefix: '10.0.0.0/24'
    sku: 'Standard'
    virtualWan: {
      id: vWan.id
    }
  }
}

resource CNUSVpn 'Microsoft.Network/vpnGateways@2020-11-01' = {
  name: 'CNUS-vpn'
  location: 'centralus'
  properties: {
    vpnGatewayScaleUnit: 1
    virtualHub: {
      id: CNUSHub.id
    }
  }
}

resource WUSHub 'Microsoft.Network/virtualHubs@2020-11-01' = {
  name: 'wus-hub'
  location: 'westus'
  properties: {
    addressPrefix: '10.1.0.0/24'
    sku: 'Standard'
    virtualWan: {
      id: vWan.id
    }
  }
}

resource WUSVpn 'Microsoft.Network/vpnGateways@2020-11-01' = {
  name: 'wus-vpn'
  location: 'westus'
  properties: {
    vpnGatewayScaleUnit: 1
    virtualHub: {
      id: WUSHub.id
    }
  }
}

resource wusRouteTableToFirewall 'Microsoft.Network/virtualHubs/hubRouteTables@2020-11-01' = {
  name: 'AllToFirewallWUS'
  parent: WUSHub
  properties: {
    routes: [
      {
        name: 'AllToFirewallWUS'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHopType: 'ResourceId'
        nextHop: fwWUS.id
      }
    ]
  }
}

resource wusRouteTableInternalToFirewall 'Microsoft.Network/virtualHubs/hubRouteTables@2020-11-01' = {
  name: 'InternalToFirewallWus'
  parent: WUSHub
  properties: {
    routes: [
      {
        name: 'InternalToFirewallWus'
        destinationType: 'CIDR'
        destinations: [
          '10.0.0.0/8'
        ]
        nextHopType: 'ResourceId'
        nextHop: fwWUS.id
      }
    ]
  }
}

resource CNUSRouteTableToFirewall 'Microsoft.Network/virtualHubs/hubRouteTables@2020-11-01' = {
  name: 'AllToFirewallCNUS'
  parent: CNUSHub
  properties: {
    routes: [
      {
        name: 'AllToFirewallCNUS'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHopType: 'ResourceId'
        nextHop: fwCNUS.id
      }
    ]
  }
}

// Networks
resource wusJump 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'wus-jump-net'
  location: 'westus'
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

resource wusJumpConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'wus-jump-connection'
  parent: WUSHub
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: wusJump.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: wusRouteTableInternalToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: wusRouteTableInternalToFirewall.id
          }
        ]
      }
    }
  }
}

resource wusSpoke1 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'wus-spoke1-net'
  location: 'westus'
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

resource wusSpoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'wus-spoke1-connection'
  parent: WUSHub
  dependsOn: [
    wusJumpConnection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: wusSpoke1.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: wusRouteTableToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: wusRouteTableToFirewall.id
          }
        ]
      }
    }
  }
}

resource wusSpoke2 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'wus-spoke2-net'
  location: 'westus'
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

resource wusSpoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'wus-spoke2-connection'
  parent: WUSHub
  dependsOn: [
    wusJumpConnection
    wusSpoke1Connection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: wusSpoke2.id
    }
    // routingConfiguration: {
    //   associatedRouteTable: {
    //     id: wusRouteTableToFirewall.id
    //   }
    //   propagatedRouteTables: {
    //     ids: [
    //       {
    //         id: wusRouteTableToFirewall.id
    //       }
    //     ]
    //   }
    // }
  }
}

resource cnusSpoke1 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'cnus-spoke1-net'
  location: 'centralus'
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

resource cnusSpoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'cnus-spoke1-connection'
  parent: CNUSHub
  dependsOn: [
    wusJumpConnection
    wusSpoke1Connection
    wusSpoke2Connection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: cnusSpoke1.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: CNUSRouteTableToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: CNUSRouteTableToFirewall.id
          }
        ]
      }
    }
  }
}

resource cnusSpoke2 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'cnus-spoke2-net'
  location: 'centralus'
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

resource cnusSpoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2020-11-01' = {
  name: 'cnus-spoke2-connection'
  parent: CNUSHub
  dependsOn: [
    wusJumpConnection
    wusSpoke1Connection
    wusSpoke2Connection
    cnusSpoke1Connection
  ]
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: cnusSpoke2.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: CNUSRouteTableToFirewall.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: CNUSRouteTableToFirewall.id
          }
        ]
      }
    }
  }
}

// Azure Firewall
resource fwPolicy 'Microsoft.Network/firewallPolicies@2020-11-01' = {
  name: 'fw-policy'
  location: 'westus'
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

resource fwWUS 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: 'fw-wus'
  location: 'westus'
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
      id: WUSHub.id
    }
  } 
}

resource fwCNUS 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: 'fw-cnus'
  location: 'centralus'
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
      id: CNUSHub.id
    }
  } 
}

// Virtual Machines
var size = 'Standard_B1ms'
var username = 'demouser'
var password = 'Azure12345678'

resource ipJump 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'jumpserver-ip'
  location: 'westus'
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nicJump 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'jumpserver-nic'
  location: 'westus'
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
            id: '${wusJump.id}/subnets/jump'
          }
        }
      }
    ]
  }
}
resource vmJump 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'jumpserver-vm'
  location: 'westus'
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
  name: 'wus-spoke1-nic'
  location: 'westus'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.4'
          subnet: {
            id: '${wusSpoke1.id}/subnets/sub1'
          }
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'wus-spoke1-vm'
  location: 'westus'
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'wus-spoke1-vm'
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
  name: 'cnus-spoke1-nic'
  location: 'centralus'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.1.1.4'
          subnet: {
            id: '${cnusSpoke1.id}/subnets/sub1'
          }
        }
      }
    ]
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'cnus-spoke1-vm'
  location: 'centralus'
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'cnus-spoke1-vm-vm'
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

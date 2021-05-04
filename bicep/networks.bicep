param fwIp string

var location = resourceGroup().location

// VNETs
resource hubNet 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'hub-net'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/20'
      ]
    }
    subnets: [
      {
        name: 'jumpserver-sub'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'sharedservices-sub'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'dmz'
        properties: {
          addressPrefix: '10.0.3.0/26'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'rp'
        properties: {
          addressPrefix: '10.0.3.128/26'
          networkSecurityGroup: {
            id: hubRpNsg.id
          }
          routeTable: {
            id: routesFromRp.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.3.192/26'
        }
      }
    ]
  }
}

resource spoke1Net 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'spoke1-net'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.16.0/20'
      ]
    }
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix: '10.0.16.0/24'
          networkSecurityGroup: {
            id: spoke1Sub1Nsg.id
          }
          routeTable: {
            id: defaultRoutes.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'sub2'
        properties: {
          addressPrefix: '10.0.17.0/24'
        }
      }
    ]
  }
}

resource spoke2Net 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: 'spoke2-net'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.32.0/20'
      ]
    }
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix: '10.0.32.0/24'
          networkSecurityGroup: {
            id: spoke2Sub1Nsg.id
          }
          routeTable: {
            id: defaultRoutes.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'paas-integration-sub'
        properties: {
          addressPrefix: '10.0.33.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
                // actions: [
                //   'Microsoft.Network/virtualNetworks/subnets/action'
                // ]
              }
            }
          ]
        }
      }
    ]
  }
}

// NSGs
resource spoke2Sub1Nsg 'Microsoft.Network/networkSecurityGroups@2017-06-01' = {
  name: 'spoke2-sub1-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowSSHFromJump'
        properties: {
          description: 'Allow SSH traffic from jump server'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.0.4/32'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'denySSH'
        properties: {
          description: 'Deny SSH traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 105
          direction: 'Inbound'
        }
      }
      {
        name: 'allowWeb'
        properties: {
          description: 'Allow web traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource spoke1Sub1Nsg 'Microsoft.Network/networkSecurityGroups@2017-06-01' = {
  name: 'spoke1-sub1-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowSSHFromJump'
        properties: {
          description: 'Allow SSH traffic from jump server'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.0.4/32'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'denySSH'
        properties: {
          description: 'Deny SSH traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 105
          direction: 'Inbound'
        }
      }
      {
        name: 'allowWeb'
        properties: {
          description: 'Allow web traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'allowPaasSql'
        properties: {
          description: 'Allow PaaS SQL traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Sql.WestEurope'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource hubRpNsg 'Microsoft.Network/networkSecurityGroups@2017-06-01' = {
  name: 'hub-rp-fw'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allowSSHFromJump'
        properties: {
          description: 'Allow SSH traffic from jump server'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.0.4/32'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'denySSH'
        properties: {
          description: 'Deny SSH traffic'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 105
          direction: 'Inbound'
        }
      }
      {
        name: 'allowWeb'
        properties: {
          description: 'Allow web ports on reverse proxy'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080-8090'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'allowAppGwManagement'
        properties: {
          description: 'Allow web ports on reverse proxy'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '65200-65535'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource defaultRoutes 'Microsoft.Network/routeTables@2018-07-01' = {
  name: 'defaultRoutes'
  location: location
  properties: {
    routes: [
      {
        name: 'defaultToNva'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fwIp
        }
      }
    ]
  }
}

resource routesFromRp 'Microsoft.Network/routeTables@2018-07-01' = {
  name: 'routesFromRp'
  location: location
  properties: {
    routes: [
      {
        name: 'defaultToNva'
        properties: {
          addressPrefix: '10.0.0.0/8'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fwIp
        }
      }
    ]
  }
}

// Web LB
resource webLb 'Microsoft.Network/loadBalancers@2020-11-01' = {
  name: 'web-lb'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'loadBalancerFrontEnd'
        properties: {
          privateIPAddress: '10.0.32.100'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${spoke2Net.id}/subnets/sub1' 
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'web-pool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'myHttpRule'
        properties: {
          frontendIPConfiguration: {
            id: '${resourceId('Microsoft.Network/loadBalancers', 'web-lb')}/frontendIpConfigurations/loadBalancerFrontEnd'
          }
          backendAddressPool: {
            id: '${resourceId('Microsoft.Network/loadBalancers', 'web-lb')}/backendAddressPools/web-pool'
          }
          probe: {
            id: '${resourceId('Microsoft.Network/loadBalancers', 'web-lb')}/probes/lbprobe'
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
        }
      }
    ]
    probes: [
      {
        name: 'lbprobe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource privateLinkService 'Microsoft.Network/privateLinkServices@2020-06-01' = {
  name: 'lb-private-link-service'
  location: location
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: webLb.properties.frontendIPConfigurations[0].id
      }
    ]
    ipConfigurations: [
      {
        name: 'application-configuration'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: '${spoke2Net.id}/subnets/sub1' 
          }
          primary: false
        }
      }
    ]
  }
}

// Private DNS
resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'net.demo'
  location: 'global'
}

resource dnsZoneSql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.database.windows.net'
  location: 'global'
}

resource dnsZoneWebApp 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

resource dnsZoneLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZone.name}/hub-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubNet.id
    }
    registrationEnabled: true
  }
}

resource dnsZoneSqlLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZoneSql.name}/hub-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubNet.id
    }
    registrationEnabled: false
  }
}

resource dnsZoneWebAppLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZoneWebApp.name}/hub-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubNet.id
    }
    registrationEnabled: false
  }
}

resource dnsZoneLinkSpoke1 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZone.name}/spoke1-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke1Net.id
    }
    registrationEnabled: true
  }
}

resource dnsZoneSqlLinkSpoke1 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZoneSql.name}/spoke1-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke1Net.id
    }
    registrationEnabled: false
  }
}

resource dnsZoneWebAppLinkSpoke1 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZoneWebApp.name}/spoke1-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke1Net.id
    }
    registrationEnabled: false
  }
}

resource dnsZoneLinkSpoke2 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZone.name}/spoke2-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke2Net.id
    }
    registrationEnabled: true
  }
}

resource dnsZoneSqlLinkSpoke2 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZoneSql.name}/spoke2-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke2Net.id
    }
    registrationEnabled: false
  }
}

resource dnsZoneWebAppLinkSpoke2 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${dnsZoneWebApp.name}/spoke2-net'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spoke2Net.id
    }
    registrationEnabled: false
  }
}

output hubNetId string = hubNet.id
output spoke1NetId string = spoke1Net.id
output spoke2NetId string = spoke2Net.id

output hubNetName string = hubNet.name
output spoke1NetName string = spoke1Net.name
output spoke2NetName string = spoke2Net.name

output webLbPoolId string = webLb.properties.backendAddressPools[0].id

output spoke1Sub1NsgId string = spoke1Sub1Nsg.id
output spoke2Sub1NsgId string = spoke2Sub1Nsg.id

output plinkServiceId string = privateLinkService.id

output webAppDnsZoneId string = dnsZoneWebApp.id

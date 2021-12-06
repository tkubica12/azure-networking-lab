param hubNetId string

var location = resourceGroup().location

resource onpremNet 'Microsoft.Network/virtualNetworks@2015-06-15' = {
  name: 'onprem-net'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.254.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'server-sub'
        properties: {
          addressPrefix: '10.254.0.0/24'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.254.1.0/24'
        }
      }
    ]
  }
}

resource onpremVpnIp 'Microsoft.Network/publicIPAddresses@2018-08-01' = {
  name: 'onprem-vpn-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: []
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vpnIp 'Microsoft.Network/publicIPAddresses@2018-08-01' = {
  name: 'vpn-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: []
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource onpremVpn 'Microsoft.Network/virtualNetworkGateways@2018-12-01' = {
  name: 'onprem-vpn'
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${onpremNet.id}/subnets/GatewaySubnet' 
          }
          publicIPAddress: {
            id: onpremVpnIp.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
  }
}

resource vpn 'Microsoft.Network/virtualNetworkGateways@2018-12-01' = {
  name: 'vpn'
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hubNetId}/subnets/GatewaySubnet' 
          }
          publicIPAddress: {
            id: vpnIp.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
  }
}

// Connections
resource onpremGw 'Microsoft.Network/localNetworkGateways@2018-12-01' = {
  name: 'onprem-gw'
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        '10.254.0.0/16'
      ]
    }
    gatewayIpAddress: onpremVpnIp.properties.ipAddress
  }
}

resource hubGw 'Microsoft.Network/localNetworkGateways@2018-12-01' = {
  name: 'hub-gw'
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: [
        '10.0.0.0/20'
      ]
    }
    gatewayIpAddress: vpnIp.properties.ipAddress
  }
}

resource vpnHubOnprem 'Microsoft.Network/connections@2018-12-01' = {
  name: 'vpn-hub-to-onprem'
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: vpn.id
      properties:{

      }
    }
    localNetworkGateway2: {
      id: onpremGw.id
      properties:{
      }
    }
    connectionType: 'IPsec'
    routingWeight: 10
    sharedKey: 'Azure12345678'
  }
}

resource vpnOnpremHub 'Microsoft.Network/connections@2018-12-01' = {
  name: 'vpn-onprem-to-hub'
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: onpremVpn.id
      properties:{

      }
    }
    localNetworkGateway2: {
      id: hubGw.id
      properties:{
        
      }
    }
    connectionType: 'IPsec'
    routingWeight: 10
    sharedKey: 'Azure12345678'
  }
}

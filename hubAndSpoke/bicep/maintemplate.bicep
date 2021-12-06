module networks 'networks.bicep' = {
  name: 'networks'
  params: {
    fwIp: '10.0.3.196'
  }
}

module vpns 'vpns.bicep' = {
  name: 'vpns'
  params: {
    hubNetId: networks.outputs.hubNetId
  }
}

module peerSpoke1 'peer.bicep' = {
  name: 'peerSpoke1'
  dependsOn: [
    vpns
    networks
  ]
  params: {
    hubId: networks.outputs.hubNetId
    hubName: networks.outputs.hubNetName
    spokeId: networks.outputs.spoke1NetId
    spokeName: networks.outputs.spoke1NetName
  }
}

module peerSpoke2 'peer.bicep' = {
  name: 'peerSpoke2'
  dependsOn: [
    vpns
    networks
  ]
  params: {
    hubId: networks.outputs.hubNetId
    hubName: networks.outputs.hubNetName
    spokeId: networks.outputs.spoke2NetId
    spokeName: networks.outputs.spoke2NetName
  }
}

module firewall 'firewall.bicep' = {
  name: 'firewall'
  params: {
    fwSubnetId: '${networks.outputs.hubNetId}/subnets/AzureFirewallSubnet' 
    logWorkspaceResourceId: monitoring.outputs.logWorkspaceResourceId
    
  }
}

module monitoring 'monitoring.bicep' = {
  name: 'monitoring'
  params: {
    spoke1Sub1NsgId: networks.outputs.spoke1Sub1NsgId
    spoke2Sub1NsgId: networks.outputs.spoke2Sub1NsgId
  }
}

module frontdoor 'frontdoor.bicep' = {
  name: 'frontdoor'
  params: {
    logWorkspaceResourceId: monitoring.outputs.logWorkspaceResourceId
    plinkServiceId: networks.outputs.plinkServiceId
    webAppUrl: webapp.outputs.webAppUrl
  }
}

module appgw 'appgw.bicep' = {
  name: 'appgw'
  params: {
    subnetId: '${networks.outputs.hubNetId}/subnets/rp'
  }
}

module webapp 'webapp.bicep' = {
  name: 'webapp'
  params: {
    integrationSubnetId: '${networks.outputs.spoke2NetId}/subnets/paas-integration-sub'
    plinkSubnetId: '${networks.outputs.hubNetId}/subnets/dmz'
    dnsZoneId: networks.outputs.webAppDnsZoneId
  }
}

module vms 'vms.bicep' = {
  name: 'vms'
  dependsOn: [
    peerSpoke1
    peerSpoke2
    firewall
  ]
  params: {
    jumpSubnetId: '${networks.outputs.hubNetId}/subnets/jumpserver-sub' 
    hubSubnetId: '${networks.outputs.hubNetId}/subnets/sharedservices-sub' 
    webSubnetId: '${networks.outputs.spoke2NetId}/subnets/sub1' 
    webLbPoolId: networks.outputs.webLbPoolId
  }
}

param integrationSubnetId string
param plinkSubnetId string
param dnsZoneId string

var location = resourceGroup().location


resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: 'app-service-plan'
  location: location
  kind: 'app'
  properties: {
    targetWorkerSizeId: 3
    targetWorkerCount: 1
  }
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
  }
}

resource webApp 'Microsoft.Web/sites@2020-12-01' = {
  name: 'web-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
  }
}

resource vnetIntegration 'Microsoft.Web/sites/networkConfig@2020-10-01' = {
  name: 'virtualNetwork'
  parent: webApp
  properties: {
    subnetResourceId: integrationSubnetId
    swiftSupported: true
  }
}

resource plink 'Microsoft.Network/privateEndpoints@2020-11-01' = {
  name: 'plink-webapp'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
          name: 'plink-webapp'
          properties: {
            privateLinkServiceId: webApp.id
            groupIds: [
              'sites'
            ]
          }
      }
    ]
    subnet: {
      id: plinkSubnetId
    }
  }
}

resource dns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = {
  name: 'default'
  parent: plink
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: dnsZoneId
        }
      }
    ]
  }
}

output webAppUrl string = '${webApp.name}.azurewebsites.net'
output webAppPlinkId string = plink.id

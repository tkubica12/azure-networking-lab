param spoke1Sub1NsgId string
param spoke2Sub1NsgId string

var location = resourceGroup().location

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: uniqueString(resourceGroup().id)
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource sentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${logWorkspace.name})'
  location: location
  plan: {
    name: 'SecurityInsights(${logWorkspace.name})'
    product: 'OMSGallery/SecurityInsights'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logWorkspace.id
  }
}

resource networkWatcher 'Microsoft.Network/networkWatchers@2020-11-01' = {
  name: 'networkWatcher-${location}'
  location: location
}

// Flow logs
resource storageFlowLogs 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: 'flow${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource flowLogSpoke1Sub1Nsg 'Microsoft.Network/networkWatchers/flowLogs@2020-11-01' = {
  name: 'flowLogSpoke1Sub1Nsg'
  location: location
  parent: networkWatcher
  properties: {
    targetResourceId: spoke1Sub1NsgId
    storageId: storageFlowLogs.id
    enabled: true
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        trafficAnalyticsInterval: 10
        workspaceResourceId: logWorkspace.id
        enabled: true
      }
    }
  } 
}

resource flowLogSpoke2Sub1Nsg 'Microsoft.Network/networkWatchers/flowLogs@2020-11-01' = {
  name: 'flowLogSpoke2Sub1Nsg'
  location: location
  parent: networkWatcher
  properties: {
    targetResourceId: spoke2Sub1NsgId
    storageId: storageFlowLogs.id
    enabled: true
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        trafficAnalyticsInterval: 10
        workspaceResourceId: logWorkspace.id
        enabled: true
      }
    }
  } 
}

output logWorkspaceResourceId string = logWorkspace.id
output logWorkspaceId string = logWorkspace.properties.customerId
output logWorkspaceName string = logWorkspace.name
output networkWatcherName string = networkWatcher.name

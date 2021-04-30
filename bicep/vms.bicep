param jumpSubnetId string
param hubSubnetId string
param webSubnetId string
param webLbPoolId string

var location = resourceGroup().location
var size = 'Standard_B1ms'
var username = 'tomas'
var password = 'Azure12345678'

var webscript = 'Y2F0ID4gL2V0Yy9zeXN0ZW1kL3N5c3RlbS9teXdlYi5zZXJ2aWNlIDw8IEVPRgpbVW5pdF0KRGVzY3JpcHRpb249TXlXZWIKCltTZXJ2aWNlXQpFeGVjU3RhcnQ9L215d2ViLnNoCgpbSW5zdGFsbF0KV2FudGVkQnk9bXVsdGktdXNlci50YXJnZXQKRU9GCgpjYXQgPiAvbXl3ZWIuc2ggPDwgRU9GCiMhL2Jpbi9iYXNoCndoaWxlIHRydWUKZG8gZWNobyAtZSAiSFRUUC8xLjEgMjAwIE9LXG5cbiBNeVdFQjogJChkYXRlKSIgfCBuYyAtbCAtdyAxIDgwCmRvbmUKRU9GCgpjaG1vZCAreCAvbXl3ZWIuc2gKc3lzdGVtY3RsIGVuYWJsZSBteXdlYgpzeXN0ZW1jdGwgc3RhcnQgbXl3ZWIK'

// Jump server
resource ipJump 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'jumpserver-ip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nicJump 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'jumpserver-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.0.4'
          publicIPAddress: {
            id: ipJump.id
          }
          subnet: {
            id: jumpSubnetId
          }
        }
      }
    ]
  }
}
resource vmJump 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'jumpserver-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'jumpserver-vm'
      adminUsername: username
      adminPassword: password
      customData: webscript
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

// Hub VM
resource nicHub 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'hub-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.4'
          subnet: {
            id: hubSubnetId
          }
        }
      }
    ]
  }
}
resource vmHub 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'hub-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'hub-vm'
      adminUsername: username
      adminPassword: password
      customData: webscript
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
          id: nicHub.id
        }
      ]
    }
  }
}

// Web1 VM
resource nicWeb1 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'web1-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.32.4'
          subnet: {
            id: webSubnetId
          }
          loadBalancerBackendAddressPools: [
            {
              id: webLbPoolId
            }
          ]
        }
      }
    ]
  }
}
resource vmWeb1 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'web1-vm'
  location: location
  zones: [
    '1'
  ]
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'web1-vm'
      adminUsername: username
      adminPassword: password
      customData: webscript
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
          id: nicWeb1.id
        }
      ]
    }
  }
}

// Web1 VM
resource nicWeb2 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'web2-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.32.5'
          subnet: {
            id: webSubnetId
          }
          loadBalancerBackendAddressPools: [
            {
              id: webLbPoolId
            }
          ]
        }
      }
    ]
  }
}
resource vmWeb2 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: 'web2-vm'
  location: location
  zones: [
    '2'
  ]
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    osProfile: {
      computerName: 'web2-vm'
      adminUsername: username
      adminPassword: password
      customData: webscript
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
          id: nicWeb2.id
        }
      ]
    }
  }
}

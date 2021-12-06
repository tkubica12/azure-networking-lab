param jumpSubnetId string
param hubSubnetId string
param webSubnetId string
param webLbPoolId string

var location = resourceGroup().location
var size = 'Standard_B1ms'
param username  string= 'demouser'
var password = 'Azure12345678'

var webscript = 'IyEvYmluL2Jhc2gKc3VkbyBhcHQgdXBkYXRlICYmIGFwdCBpbnN0YWxsIG5naW54IC15CmVjaG8gSGVsbG8gZnJvbSAkKGhvc3RuYW1lKSA+IC92YXIvd3d3L2h0bWwvaW5kZXguaHRtbA=='

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

// Web2 VM
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

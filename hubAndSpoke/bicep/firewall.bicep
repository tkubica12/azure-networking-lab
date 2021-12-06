param fwSubnetId string
param logWorkspaceResourceId string


var location = resourceGroup().location

resource fwIp 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'fw-ip'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fwBasePolicy 'Microsoft.Network/firewallPolicies@2020-07-01' = {
  name: 'fw-base-policy'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${fwIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      tier: 'Premium'
    }
    intrusionDetection: {
      mode: 'Deny'
    }
    threatIntelMode: 'Deny'
    transportSecurity: {
      certificateAuthority: {
        name: 'cert'
        keyVaultSecretId: scriptCreateCertificate.properties.outputs['result'][0]
      }
    }
  }
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2020-07-01' = {
  name: 'fw-policy'
  dependsOn: [
    fwBasePolicy
    fwBasesRulesApp
  ]
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${fwIdentity.id}': {}
    }
  }
  properties: {
    basePolicy: {
      id: fwBasePolicy.id
    }
    sku: {
      tier: 'Premium'
    }
    intrusionDetection: {
      mode: 'Deny'
    }
    threatIntelMode: 'Deny'
    transportSecurity: {
      certificateAuthority: {
        name: 'cert'
        keyVaultSecretId: scriptCreateCertificate.properties.outputs['result'][0]
      }
    }
  }
}

resource fwBasesRulesApp 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  name: '${fwBasePolicy.name}/DefaultApplicationRuleCollectionGroup'
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

resource fwRulesApp 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  name: '${fwPolicy.name}/DefaultApplicationRuleCollectionGroup'
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
            name: 'microsoft'
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
            targetFqdns: [
              '*microsoft.com'
            ]
            terminateTLS: false
          }
        ]
      }
      {
        name: 'allowUbuntu'
        priority: 110
        action: {
          type: 'Allow'
        }
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'ubuntu'
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
            targetFqdns: [
              '*ubuntu.com'
            ]
            terminateTLS: false
          }
        ]
      }
      {
        name: 'allowGithub'
        priority: 120
        action: {
          type: 'Allow'
        }
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'github'
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
            targetFqdns: [
              '*github.com'
            ]
            terminateTLS: false
          }
        ]
      }
      {
        name: 'allowMaliciousTest'
        priority: 130
        action: {
          type: 'Allow'
        }
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'clicnews.com'
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
            targetFqdns: [
              'clicnews.com'
            ]
            terminateTLS: false
          }
        ]
      }
    ]
  }
}

resource fwRulesNet 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  name: '${fwPolicy.name}/DefaultNetworkRuleCollectionGroup'
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
            name: 'allowWeb'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
            ]
            destinationAddresses: [
              '10.0.0.0/8'
            ]
            destinationPorts: [
              '80'
            ]
          }
          {
            name: 'allowSsh'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/8'
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

resource fw 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: 'fw'
  location: location
  dependsOn: [
    fwBasePolicy
    fwBasesRulesApp
    fwRulesApp
    fwRulesNet
  ]
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      tier: 'Premium'
    }
    firewallPolicy: {
      id: fwPolicy.id
    }
    ipConfigurations: [
      {
        name: fwIp.name
        properties: {
          subnet: {
            id: fwSubnetId
          }
          publicIPAddress: {
            id: fwIp.id
          }
        }
      }
    ]
  }
}

// Certificate
resource fwIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'fwIdentity'
  location: location
}

resource fwKeyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: fwIdentity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          certificates: [
            'all'
          ]
          secrets: [
            'all'
          ]
          keys: [
            'all'
          ]
        }
      }
    ]
    enableRbacAuthorization: false
  }
}

resource fwKeyVaultRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('fwKeyVaultRole', resourceGroup().id)
  scope: fwKeyVault
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
    principalId: fwIdentity.properties.principalId
  }
}

resource fwContributorRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('fwContributorRole', resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: fwIdentity.properties.principalId
  }
}

resource scriptCreateCertificate 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'scriptCreateCertificate'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
        '${fwIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.20.0'
    cleanupPreference: 'OnExpiration'
    scriptContent: '''
      wget https://github.com/tkubica12/azure-networking-lab/blob/master/bicep/inspectionCert/interCA.pfx?raw=true -O interCA.pfx
      az keyvault certificate import -n cert --vault-name $kv -f interCA.pfx --password Azure12345678
      echo {\"result\":[\"$(az keyvault certificate show -n cert --vault-name $kv --query sid -o tsv)\"]} > $AZ_SCRIPTS_OUTPUT_PATH
    '''
    environmentVariables: [
      {
        name: 'kv'
        value: fwKeyVault.name
      }
    ]
    retentionInterval: 'P1D'
  }
}

resource fwDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview'= {
  scope: fw
  name: 'logs'
  properties: {
    workspaceId: logWorkspaceResourceId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

output keyVaultName string = fwKeyVault.name

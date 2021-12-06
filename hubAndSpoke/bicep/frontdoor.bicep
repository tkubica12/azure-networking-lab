param plinkServiceId string
param webAppUrl string
param logWorkspaceResourceId string

resource fdProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: 'frontdoor-profile'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}

resource fdEndpointLb 'Microsoft.Cdn/profiles/afdEndpoints@2020-09-01' = {
  name: 'fd-lb-plink${uniqueString(resourceGroup().id)}'
  parent: fdProfile
  location: 'global'
  properties: {
    originResponseTimeoutSeconds: 240
    enabledState: 'Enabled'
  }
}

resource fdEndpointAppGw 'Microsoft.Cdn/profiles/afdEndpoints@2020-09-01' = {
  name: 'fd-appgw-plink${uniqueString(resourceGroup().id)}'
  parent: fdProfile
  location: 'global'
  properties: {
    originResponseTimeoutSeconds: 240
    enabledState: 'Enabled'
  }
}

resource fdOriginGroupLb 'Microsoft.Cdn/profiles/originGroups@2020-09-01' = {
  name: 'web-lb'
  parent: fdProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
  }
}

resource fdOriginGroupAppGw 'Microsoft.Cdn/profiles/originGroups@2020-09-01' = {
  name: 'web-appgw'
  parent: fdProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
  }
}

resource fdOriginWebLb 'Microsoft.Cdn/profiles/originGroups/origins@2020-09-01' = {
  name: 'web-lb'
  parent: fdOriginGroupLb
  properties: {
    hostName: '10.0.32.100'
    httpPort: 80
    httpsPort: 443
    originHostHeader: '10.0.32.100'
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: {
      privateLinkLocation: 'eastus'
      requestMessage: 'This is authorization from Front Door'
      privateLink: {
        id: plinkServiceId
      }
    }
  }
}

resource fdOriginWebAppGw 'Microsoft.Cdn/profiles/originGroups/origins@2020-09-01' = {
  name: 'web-appgw'
  parent: fdOriginGroupLb
  properties: {
    hostName: webAppUrl
    httpPort: 80
    httpsPort: 443
    originHostHeader: webAppUrl
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: {
      privateLinkLocation: 'eastus'
      requestMessage: 'This is authorization from Front Door'
      privateLink: {
        id: plinkServiceId
      }
    }
  }
}

resource routeWebLb 'Microsoft.Cdn/profiles/afdEndpoints/routes@2020-09-01' = {
  name: 'web-route'
  parent: fdEndpointLb
  dependsOn: [
    fdOriginWebLb
  ]
  properties: {
    originGroup: {
      id: fdOriginGroupLb.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    compressionSettings: {
      contentTypesToCompress: [
        'application/eot'
        'application/font'
        'application/font-sfnt'
        'application/javascript'
        'application/json'
        'application/opentype'
        'application/otf'
        'application/pkcs7-mime'
        'application/truetype'
        'application/ttf'
        'application/vnd.ms-fontobject'
        'application/xhtml+xml'
        'application/xml'
        'application/xml+rss'
        'application/x-font-opentype'
        'application/x-font-truetype'
        'application/x-font-ttf'
        'application/x-httpd-cgi'
        'application/x-javascript'
        'application/x-mpegurl'
        'application/x-opentype'
        'application/x-otf'
        'application/x-perl'
        'application/x-ttf'
        'font/eot'
        'font/ttf'
        'font/otf'
        'font/opentype'
        'image/svg+xml'
        'text/css'
        'text/csv'
        'text/html'
        'text/javascript'
        'text/js'
        'text/plain'
        'text/richtext'
        'text/tab-separated-values'
        'text/xml'
        'text/x-script'
        'text/x-component'
        'text/x-java-source'
      ]
      isCompressionEnabled: false
    }
    queryStringCachingBehavior: 'NotSet'
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource routeWebAppGw 'Microsoft.Cdn/profiles/afdEndpoints/routes@2020-09-01' = {
  name: 'web-route-appgw'
  parent: fdEndpointLb
  dependsOn: [
    fdOriginWebAppGw
  ]
  properties: {
    originGroup: {
      id: fdOriginGroupAppGw.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    compressionSettings: {
      contentTypesToCompress: [
        'application/eot'
        'application/font'
        'application/font-sfnt'
        'application/javascript'
        'application/json'
        'application/opentype'
        'application/otf'
        'application/pkcs7-mime'
        'application/truetype'
        'application/ttf'
        'application/vnd.ms-fontobject'
        'application/xhtml+xml'
        'application/xml'
        'application/xml+rss'
        'application/x-font-opentype'
        'application/x-font-truetype'
        'application/x-font-ttf'
        'application/x-httpd-cgi'
        'application/x-javascript'
        'application/x-mpegurl'
        'application/x-opentype'
        'application/x-otf'
        'application/x-perl'
        'application/x-ttf'
        'font/eot'
        'font/ttf'
        'font/otf'
        'font/opentype'
        'image/svg+xml'
        'text/css'
        'text/csv'
        'text/html'
        'text/javascript'
        'text/js'
        'text/plain'
        'text/richtext'
        'text/tab-separated-values'
        'text/xml'
        'text/x-script'
        'text/x-component'
        'text/x-java-source'
      ]
      isCompressionEnabled: false
    }
    queryStringCachingBehavior: 'NotSet'
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource fdDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview'= {
  scope: fdProfile
  name: 'logs'
  properties: {
    workspaceId: logWorkspaceResourceId
    logs: [
      {
        category: 'FrontDoorAccessLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'FrontDoorHealthProbeLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'FrontDoorWebApplicationFirewallLog'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}


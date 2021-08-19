param location string = resourceGroup().location
param tags object = {

}
param appgwSubnetId string
param appgwName string
param appgwPrivateIP string
param minCapacity int = 2
param maxCapacity int = 3
param frontendPort int = 80
param backendPort int = 80
param backendAddressPools array = [
  {
    name: 'appgw-UIBackendPool'
  }
  {
    name: 'appgw-ProxyBackendPool'
  }
  {
    name: 'appgw-CoreBackendPool'
  }
]

@allowed([
  'Enabled'
  'Disabled'
])
param cookieBasedAffinity string = 'Disabled'

// variables
var appGwPublicIpName = '${appgwName}-pip'

resource publicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: appGwPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource appgw 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: appgwName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appgwSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appgwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
      {
        name: 'appgwPrivateFrontendIp'
        properties: {
          privateIPAddress: appgwPrivateIP
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: appgwSubnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'appgwFrontendPort'
        properties: {
          port: frontendPort
        }
      }
    ]
    backendAddressPools: [for backendAddressPool in backendAddressPools: {
      name: backendAddressPool.name
    }]
    backendHttpSettingsCollection: [
      {
        name: 'appgwBackendHttpSettings'
        properties: {
          port: backendPort
          protocol: 'Http'
          cookieBasedAffinity: cookieBasedAffinity
        }
      }
    ]
    httpListeners: [
      {
        name: 'appgwHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appgwName, 'appgwPrivateFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwName, 'appgwFrontendPort')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'http-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appgwName, 'appgwHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwName, 'appgw-UIBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwName, 'appgwBackendHttpSettings')
          }
        }
      }
    ]
  }
}

output appgwID string = appgw.id
output appgwBackendAddressPool array = [for (backendAddressPool,i) in backendAddressPools:{
  name: appgw.properties.backendAddressPools[i].name
  id: appgw.properties.backendAddressPools[i].id
}]

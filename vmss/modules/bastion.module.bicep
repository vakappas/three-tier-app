// Parameters
param location string = 'northeurope'

param tags object = {
}

// bastion host name
param bastionHostName string = 'hub-bastion'
param bastionSubnetId string

// variables

resource bastionHostPip 'Microsoft.Network/publicIpAddresses@2020-05-01' = {
  name: '${bastionHostName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-06-01'= {
  name: bastionHostName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: '${bastionHostName}-ipconfig'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionHostPip.id
          }
        }
      }
    ]
  }
}

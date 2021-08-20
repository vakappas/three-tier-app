// Parameters section
param vnetName string = 'vnet'
param vnetPrefix string = '172.16.0.0/22'
param vnetdnsservers array

@description('Subnets to be created as array of objects, "name" and "subnetPrefix" properties are required, optionally include "routeTableid" and "privateEndpointNetworkPolicies" as "Enabled"/"Disabled"')
param subnets array = [
  {
    name: 'subnet1'
    subnetPrefix: '172.16.0.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
  }
  {
    name: 'subnet2'
    subnetPrefix: '172.16.1.0/24'
    routeTableid: ''
    privateEndpointNetworkPolicies: 'Disabled'
  }
  {
    name: 'subnet3'
    subnetPrefix: '172.16.2.0/24'
  }
]
param tags object = {

}

// Variables Section

// Default values for optional properties
var subnetDefaults = {
  routeTableid: ''
  privateEndpointNetworkPolicies: 'Disabled'
  networkSecurityGroupid: ''
}

// Normalize subnets passed as parameter applying the default values
var normalizedSubnets = [for subnet in subnets: union(subnetDefaults, subnet)]

resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' = {
  name: vnetName
  location: resourceGroup().location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: vnetdnsservers
    }
    enableVmProtection: false
    enableDdosProtection: false
    subnets:[for subnet in normalizedSubnets: {
      name:subnet.name
      properties:{
        addressPrefix:subnet.subnetPrefix
        privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
        routeTable: empty(subnet.routeTableid) ? json('null') : {
          id: subnet.routeTableid
        }
        networkSecurityGroup: empty(subnet.networkSecurityGroupid) ? json('null') : {
          id: subnet.networkSecurityGroupid
        }
      }
    }]
  }
}


output vnetID string = vnet.id
output subnet array = [for (subnet,i) in subnets:{
  name: vnet.properties.subnets[i].name
  subnetID: vnet.properties.subnets[i].id
}]

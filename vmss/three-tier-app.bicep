// set the target scope to subscription
targetScope = 'subscription'

// parameters
param prefix string = 'three-tier-app'
param location string = 'northeurope'

@secure()
param adminpassword string

// Variables
var tags = {
  environment: 'lab'
  projectCode: 'three-tier-app'
}
var vnetName = '${prefix}-vnet'
var bastionName = '${prefix}-bastion'

// create resource groups
resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: 'rg-${prefix}'
  location: location
  tags: tags
}

// Create NSG for bastion subnet
module bastionSubnetNsg 'modules/bastionnsg.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${bastionName}-nsg'
  params: {
    bastionHostName: bastionName
  }
}
// Create vnet
module vnet 'modules/vnet.module.bicep' = {
  name: vnetName
  scope: resourceGroup(rg.name)
  params: {
    tags: tags
    vnetName: vnetName
    vnetPrefix: '192.168.1.0/24'
    subnets: [
      {
        name: 'AzureBastionSubnet'
        subnetPrefix: '192.168.1.0/27'
        networkSecurityGroupid: bastionSubnetNsg.outputs.bastionSubnetNsgId
      }
      {
        name: 'appgw-subnet'
        subnetPrefix: '192.168.1.32/27'
        privateEndpointNetworkPolicies: 'Enabled'
      }
      {
        name: 'fe-subnet'
        subnetPrefix: '192.168.1.64/27'
        privateEndpointNetworkPolicies: 'Enabled'
      }
      {
        name: 'proxy-subnet'
        subnetPrefix: '192.168.1.96/27'
        privateEndpointNetworkPolicies: 'Enabled'
      }
      {
        name: 'core-subnet'
        subnetPrefix: '192.168.1.128/27'
        privateEndpointNetworkPolicies: 'Enabled'
      }
      {
        name: 'db-subnet'
        subnetPrefix: '192.168.1.160/27'
        privateEndpointNetworkPolicies: 'Enabled'
      }
    ]
  }
}
// Create bastion
module bastion 'modules/bastion.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: bastionName
  params: {
    tags: tags
    bastionHostName: bastionName
    bastionSubnetId: vnet.outputs.subnet[0].subnetID
  }
}

// Create application gateway
module appgw 'modules/appgw.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${prefix}-appgw'
  params: {
    appgwName: '${prefix}-appgw'
    appgwSubnetId: vnet.outputs.subnet[1].subnetID
    appgwPrivateIP: '192.168.1.36'
  }
}

// Create UI vmss
module ui 'modules/vmss.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${prefix}-ui'
  params: {
    adminPassword: adminpassword
    vmssName: 'ui'
    vmssSubnetId: vnet.outputs.subnet[2].subnetID
    appgwBackendPoolId: appgw.outputs.appgwBackendAddressPool[0].id
  }
}
// Create proxy vmss
module proxy 'modules/vmss.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${prefix}-proxy'
  params: {
    adminPassword: adminpassword
    vmssName: 'proxy'
    vmssSubnetId: vnet.outputs.subnet[3].subnetID
    appgwBackendPoolId: appgw.outputs.appgwBackendAddressPool[1].id
  }
}
// Create core vmss
module core 'modules/vmss.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${prefix}-core'
  params: {
    adminPassword: adminpassword
    vmssName: 'core'
    vmssSubnetId: vnet.outputs.subnet[4].subnetID
    appgwBackendPoolId: appgw.outputs.appgwBackendAddressPool[2].id
  }
}

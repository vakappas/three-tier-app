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

// Create proxy vmss
module proxy 'modules/vmss.module.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${prefix}-proxy'
  params: {
    adminPassword: adminpassword
    vmssName: 'proxy'
    vmssSubnetId: vnet.outputs.subnet[3].subnetID
  }
}


git config --global user.email "you@example.com"
  git config --global user.name "Your Name"
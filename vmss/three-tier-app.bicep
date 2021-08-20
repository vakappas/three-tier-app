// set the target scope to subscription
targetScope = 'subscription'

// parameters
param prefix string = 'three-tier-app'
param location string = 'northeurope'

@secure()
param adminpassword string

// Domain Join parameters
param domainToJoin string
param domainJoinerUser string
@secure()
param domainJoinerPass string
param ouPath string = 'OU=VMSS,DC=vklab,DC=eu'

// Variables
var tags = {
  environment: 'lab'
  projectCode: 'three-tier-app'
}
var vnetName = '${prefix}-vnet'
var bastionName = '${prefix}-bastion'

// Getting the existing resource group
resource wvdrg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: 'WVD-Lab-RG'
}

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
    vnetdnsservers: [
      '172.16.1.11'
    ]
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
module wvdvnet 'modules/vnet.existing.module.bicep' = {
  scope: resourceGroup(wvdrg.name)
  name: 'wvdvnet'
  params: {
    existingvnetName: 'vklab1-vnet'
  }
}
module wvdtovnetpeering './modules/vnet.peering.bicep' = {
  name: 'wvd-to-vnet'
  scope: resourceGroup(wvdrg.name)
  params: {
    localVnetName: wvdvnet.outputs.existingvnetName
    remoteVnetName: vnet.name
    remoteVnetRg: rg.name
    remoteVnetID: vnet.outputs.vnetID
  }
}
module vnettowvdpeering './modules/vnet.peering.bicep' = {
  name: 'vnet-to-wvd'
  scope: resourceGroup(rg.name)
  params: {
    localVnetName: vnet.name
    remoteVnetName: wvdvnet.outputs.existingvnetName
    remoteVnetRg: wvdrg.name
    remoteVnetID: wvdvnet.outputs.existingvnetId
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
    domainToJoin: domainToJoin
    domainJoinerUser: domainJoinerUser
    domainJoinerPass: domainJoinerPass
    ouPath: ouPath
  }
}

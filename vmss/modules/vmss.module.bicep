param tags object = {

}
param vmSku string = 'Standard_D2s_v3'

@allowed([
  '2019-Datacenter'
  '2016-Datacenter'
  '2012-R2-Datacenter'
  '2012-Datacenter'
])
param windowsOSVersion string = '2019-Datacenter'

@maxLength(61)
param vmssName string

param vmssSubnetId string

@minValue(1)
@maxValue(100)
param instanceCount int = 2

param adminUsername string = 'vmssadmin'

@secure()
param adminPassword string

param location string = resourceGroup().location

// variables
var namingInfix = toLower(substring('${vmssName}${uniqueString(resourceGroup().id)}', 0, 9))
var longNamingInfix = toLower(vmssName)
var natPoolName = '${namingInfix}-natpool'
var bePoolName = '${namingInfix}-bepool'
var natStartPort = 50000
var natEndPort = 50119
var natBackendPort = 3389
var nicname = '${namingInfix}-nic'
var ipConfigName = '${namingInfix}-ipconfig'
var osType = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: windowsOSVersion
  version: 'latest'
}
var imageReference = osType

// Resources
resource ilb 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: '${longNamingInfix}-ilb'
  tags: tags
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          privateIPAddress: '${longNamingInfix}-pip'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmssSubnetId
          }
        }
        
      }
      
    ]
    backendAddressPools: [
      {
        name: bePoolName
      }
    ]

  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2020-06-01' = {
  name: vmssName
  tags: tags
  location: location
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: true
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: namingInfix
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicname
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: ipConfigName
                  properties: {
                    subnet: {
                      id: vmssSubnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: ilb.properties.backendAddressPools[0].id
                      }
                    ]

                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

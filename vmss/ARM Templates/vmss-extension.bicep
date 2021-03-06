@description('Size of VMs in the VM Scale Set.')
param vmSku string = 'Standard_A1_v2'

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version. Allowed values: 2008-R2-SP1, 2012-Datacenter, 2012-R2-Datacenter & 2016-Datacenter, 2019-Datacenter.')
@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2016-Datacenter'
  '2019-Datacenter'
])
param windowsOSVersion string = '2019-Datacenter'

@description('String used as a base for naming resources. Must be 3-61 characters in length and globally unique across Azure. A hash is prepended to this string for some resources, and resource-specific information is appended.')
@minLength(3)
@maxLength(61)
param vmssName string

@description('Number of VM instances (100 or less).')
@minValue(1)
@maxValue(100)
param instanceCount int = 3

@description('When true this limits the scale set to a single placement group, of max size 100 virtual machines. NOTE: If singlePlacementGroup is true, it may be modified to false. However, if singlePlacementGroup is false, it may not be modified to true.')
param singlePlacementGroup bool = true

@description('Admin username on all VMs.')
param adminUsername string = 'vmssadmin'

@description('Admin password on all VMs.')
@secure()
param adminPassword string

@description('The base URI where artifacts required by this template are located. For example, if stored on a public GitHub repo, you\'d use the following URI: https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/201-vmss-windows-webapp-dsc-autoscale/.')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  If your artifacts are stored on a public repo or public storage account you can leave this blank.')
@secure()
param artifactsLocationSasToken string = ''

@description('Location of the PowerShell DSC zip file relative to the URI specified in the _artifactsLocation, i.e. DSC/IISInstall.ps1.zip')
param powershelldscZip string = 'DSC/InstallIIS.zip'

@description('Location of the  of the WebDeploy package zip file relative to the URI specified in _artifactsLocation, i.e. WebDeploy/DefaultASPWebApp.v1.0.zip')
param webDeployPackage string = 'WebDeploy/DefaultASPWebApp.v1.0.zip'

@description('Version number of the DSC deployment. Changing this value on subsequent deployments will trigger the extension to run.')
param powershelldscUpdateTagVersion string = '1.0'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Fault Domain count for each placement group.')
param platformFaultDomainCount int = 1

var namingInfix_var = toLower(substring(concat(vmssName, uniqueString(resourceGroup().id)), 0, 9))
var longNamingInfix = toLower(vmssName)
var addressPrefix = '10.0.0.0/16'
var subnetPrefix = '10.0.0.0/24'
var virtualNetworkName_var = '${namingInfix_var}vnet'
var publicIPAddressName_var = '${namingInfix_var}pip'
var subnetName = '${namingInfix_var}subnet'
var loadBalancerName_var = '${namingInfix_var}lb'
var publicIPAddressID = publicIPAddressName.id
var lbProbeID = resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName_var, 'tcpProbe')
var natPoolName = '${namingInfix_var}natpool'
var bePoolName = '${namingInfix_var}bepool'
var lbPoolID = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName_var, bePoolName)
var natStartPort = 50000
var natEndPort = 50119
var natBackendPort = 3389
var nicName = '${namingInfix_var}nic'
var ipConfigName = '${namingInfix_var}ipconfig'
var frontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName_var, 'loadBalancerFrontEnd')
var osType = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: windowsOSVersion
  version: 'latest'
}
var imageReference = osType
var webDeployPackageFullPath = uri(artifactsLocation, concat(webDeployPackage, artifactsLocationSasToken))
var powershelldscZipFullPath = uri(artifactsLocation, concat(powershelldscZip, artifactsLocationSasToken))

resource loadBalancerName 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: loadBalancerName_var
  location: location
  properties: {
    frontendIPConfigurations: [
      {
        name: 'LoadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: publicIPAddressID
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: bePoolName
      }
    ]
    inboundNatPools: [
      {
        name: natPoolName
        properties: {
          frontendIPConfiguration: {
            id: frontEndIPConfigID
          }
          protocol: 'Tcp'
          frontendPortRangeStart: natStartPort
          frontendPortRangeEnd: natEndPort
          backendPort: natBackendPort
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'LBRule'
        properties: {
          frontendIPConfiguration: {
            id: frontEndIPConfigID
          }
          backendAddressPool: {
            id: lbPoolID
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 5
          probe: {
            id: lbProbeID
          }
        }
      }
    ]
    probes: [
      {
        name: 'tcpProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource namingInfix 'Microsoft.Compute/virtualMachineScaleSets@2020-06-01' = {
  name: namingInfix_var
  location: location
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: true
    upgradePolicy: {
      mode: 'Automatic'
    }
    singlePlacementGroup: singlePlacementGroup
    platformFaultDomainCount: platformFaultDomainCount
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          caching: 'ReadWrite'
          createOption: 'FromImage'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: namingInfix_var
        adminUsername: adminUsername
        adminPassword: adminPassword
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: ipConfigName
                  properties: {
                    subnet: {
                      id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, subnetName)
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: lbPoolID
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', loadBalancerName_var, natPoolName)
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'Microsoft.Powershell.DSC'
            properties: {
              publisher: 'Microsoft.Powershell'
              type: 'DSC'
              typeHandlerVersion: '2.9'
              autoUpgradeMinorVersion: true
              forceUpdateTag: powershelldscUpdateTagVersion
              settings: {
                configuration: {
                  url: powershelldscZipFullPath
                  script: 'InstallIIS.ps1'
                  function: 'InstallIIS'
                }
                configurationArguments: {
                  nodeName: 'localhost'
                  WebDeployPackagePath: webDeployPackageFullPath
                }
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    loadBalancerName
    virtualNetworkName
  ]
}

resource publicIPAddressName 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: publicIPAddressName_var
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: longNamingInfix
    }
  }
}

resource virtualNetworkName 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: virtualNetworkName_var
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

resource autoscalehost 'Microsoft.Insights/autoscaleSettings@2015-04-01' = {
  name: 'autoscalehost'
  location: location
  properties: {
    name: 'autoscalehost'
    targetResourceUri: namingInfix.id
    enabled: true
    profiles: [
      {
        name: 'Profile1'
        capacity: {
          minimum: '1'
          maximum: '10'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: namingInfix.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 50
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: namingInfix.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

output applicationUrl string = 'http://${publicIPAddressName.properties.dnsSettings.fqdn}/MyApp'
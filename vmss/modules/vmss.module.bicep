param location string = resourceGroup().location
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
param appgwBackendPoolId string
@minValue(1)
@maxValue(100)
param instanceCount int = 2
param adminUsername string = 'vmssadmin'
@secure()
param adminPassword string

@description('The base URI where artifacts required by this template are located. For example, if stored on a public GitHub repo, you\'d use the following URI: https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/201-vmss-windows-webapp-dsc-autoscale/.')
param artifactsLocation string = 'https://github.com/Azure/azure-quickstart-templates/raw/master/demos/vmss-windows-webapp-dsc-autoscale/'
@description('The sasToken required to access _artifactsLocation.  If your artifacts are stored on a public repo or public storage account you can leave this blank.')
@secure()
param artifactsLocationSasToken string = ''

@description('Version number of the DSC deployment. Changing this value on subsequent deployments will trigger the extension to run.')
param powershelldscUpdateTagVersion string = '1.0'

@description('Location of the PowerShell DSC zip file relative to the URI specified in the _artifactsLocation, i.e. DSC/IISInstall.ps1.zip')
param powershelldscZip string = 'DSC/InstallIIS.zip'

@description('Location of the  of the WebDeploy package zip file relative to the URI specified in _artifactsLocation, i.e. WebDeploy/DefaultASPWebApp.v1.0.zip')
param webDeployPackage string = 'WebDeploy/DefaultASPWebApp.v1.0.zip'

// Domain Join parameters
param domainToJoin string
param ouPath string
param domainJoinerUser string
param domainJoinerPass string
@description('Set of bit flags that define the join options. Default value of 3 is a combination of NETSETUP_JOIN_DOMAIN (0x00000001) & NETSETUP_ACCT_CREATE (0x00000002) i.e. will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx')
param domainJoinOptions int = 3

// variables
var namingInfix = toLower(substring('${vmssName}${uniqueString(resourceGroup().id)}', 0, 9))
var longNamingInfix = toLower(vmssName)
var bePoolName = '${namingInfix}-bepool'
var nicname = '${namingInfix}-nic'
var ipConfigName = '${namingInfix}-ipconfig'
var osType = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: windowsOSVersion
  version: 'latest'
}
var imageReference = osType

var webDeployPackageFullPath = uri(artifactsLocation, concat(webDeployPackage, artifactsLocationSasToken))
var powershelldscZipFullPath = uri(artifactsLocation, concat(powershelldscZip, artifactsLocationSasToken))


// Resources

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
                    applicationGatewayBackendAddressPools: [
                       {
                         id: appgwBackendPoolId
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
          {
            name: 'joindomain'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'JsonADDomainExtension'
              typeHandlerVersion: '1.3'
              autoUpgradeMinorVersion: true
              settings: {
                name: domainToJoin
                ouPath: ouPath
                user: domainJoinerUser
                restart: true
                options: domainJoinOptions         
              }
              protectedSettings: {
                Password: domainJoinerPass
              }
            }
          }
        ]
      }
    }
    
  }
}


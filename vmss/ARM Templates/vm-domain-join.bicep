@description('Size of VM')
param vmSize string = 'Standard_A2_v2'

@description('Existing VNET that contains the domain controller')
param existingVnetName string

@description('Public IP address name')
param publicIPAddressName string = '${dnsLabelPrefix}-pip'

@description('Existing subnet that contains the domain controller')
param existingSubnetName string

@description('Unique public DNS prefix for the deployment. The fqdn will look something like \'<dnsname>.westus.cloudapp.azure.com\'. Up to 62 chars, digits or dashes, lowercase, should start with a letter: must conform to \'^[a-z][a-z0-9-]{1,61}[a-z0-9]$\'.')
@minLength(1)
@maxLength(62)
param dnsLabelPrefix string

@description('The FQDN of the AD domain')
param domainToJoin string

@description('Username of the account on the domain')
param domainUsername string

@description('Password of the account on the domain')
@secure()
param domainPassword string

@description('Organizational Unit path in which the nodes and cluster will be present.')
param ouPath string = ''

@description('Set of bit flags that define the join options. Default value of 3 is a combination of NETSETUP_JOIN_DOMAIN (0x00000001) & NETSETUP_ACCT_CREATE (0x00000002) i.e. will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx')
param domainJoinOptions int = 3

@description('The name of the administrator of the new VM.')
param adminUsername string

@description('The password for the administrator account of the new VM.')
@secure()
param adminPassword string

@description('The name of the storage account.')
param storageAccountName string = uniqueString(resourceGroup().id, deployment().name)

@description('Location for all resources.')
param location string = resourceGroup().location

var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var windowsOSVersion = '2019-Datacenter'
var nicName_var = '${dnsLabelPrefix}-nic'

resource publicIPAddressName_resource 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: publicIPAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource storageAccountName_resource 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource nicName 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: nicName_var
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressName_resource.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', existingVnetName, existingSubnetName)
          }
        }
      }
    ]
  }
}

resource dnsLabelPrefix_resource 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: dnsLabelPrefix
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: dnsLabelPrefix
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: windowsOSVersion
        version: 'latest'
      }
      osDisk: {
        name: '${dnsLabelPrefix}-OsDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
      dataDisks: [
        {
          name: '${dnsLabelPrefix}-DataDisk'
          caching: 'None'
          createOption: 'Empty'
          diskSizeGB: 1024
          lun: 0
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicName.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccountName_resource.properties.primaryEndpoints.blob
      }
    }
  }
}

resource dnsLabelPrefix_joindomain 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: dnsLabelPrefix_resource
  name: 'joindomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainToJoin
      ouPath: ouPath
      user: '${domainToJoin}\\${domainUsername}'
      restart: true
      options: domainJoinOptions
    }
    protectedSettings: {
      Password: domainPassword
    }
  }
}
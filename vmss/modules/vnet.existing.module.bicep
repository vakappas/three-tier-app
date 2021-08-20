param existingvnetName string

resource existingvnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: existingvnetName
}

output existingvnetId string = existingvnet.id
output existingvnetName string = existingvnet.name

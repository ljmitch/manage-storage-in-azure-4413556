
@description('Location for all resources.')
param location string

@description('Suffix for resources.')
param suffix string

@description('Address prefix for vnet.')
param addressPrefix string

@description('Subnet prefix.')
param subnetPrefix string

@description('Subnet prefix.')
param plinkSubnetPrefix string

var subnetName = 'snet-${suffix}'

var plinkSubnetName = 'snet-plink-${suffix}'

var virtualNetworkName = 'vnet-${suffix}'
var networkSecurityGroupName = 'nsg-${suffix}'

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'RDP-Allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: virtualNetworkName
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
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: plinkSubnetName
        properties: {
          addressPrefix: plinkSubnetPrefix
        }
      }
    ]
  }
}



output workloadVNetName string = virtualNetwork.name
output workloadSubnetName string = virtualNetwork.properties.subnets[0].name

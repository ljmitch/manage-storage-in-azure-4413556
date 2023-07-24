// Creates a storage account, private endpoints and DNS zones, virtual Network and Virtual Machine
@description('Azure region of the deployment')
param location string

@description('Password for the Virtual Machine.')
@minLength(12)
@secure()
param adminPassword string

@description('Storage prefix for the file share storage account')
@maxLength(4)
param resourcePrefix string


@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Premium_LRS'
  'Premium_ZRS'
])

@description('Storage SKU')
param storageSkuName string = 'Standard_LRS'

var storageName = 'sa${resourcePrefix}${uniqueString(resourceGroup().id)}'

var filePrivateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'

module vmAndNetwork 'vm-network.bicep' = {
  name: 'vm-mas0501'
  params: {
    adminPassword: adminPassword
    location: location
    resourcePrefix: resourcePrefix
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    isHnsEnabled: false
    isNfsV3Enabled: false
    keyPolicy: {
      keyExpirationPeriodInDays: 7
    }
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource storagePrivateEndpointFile 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'plf-${storage.name}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'plf-${storage.name}'
        properties: {
          groupIds: [
            'file'
          ]
          privateLinkServiceId: storage.id
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Auto-Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    subnet: {
      id: vmAndNetwork.outputs.subnetId
    }
  }
}

resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: filePrivateDnsZoneName
  location: 'global'
}

resource filePrivateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  name: storage.name
  parent: storagePrivateEndpointFile
  properties:{
    privateDnsZoneConfigs: [
      {
        name: filePrivateDnsZoneName
        properties:{
          privateDnsZoneId: filePrivateDnsZone.id
        }
      }
    ]
  }
}

resource filePrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'vnet-${resourcePrefix}-link'
  parent: filePrivateDnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vmAndNetwork.outputs.vnetId
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-08-01' = {
  name: 'default'
  parent: storage
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-08-01' = {
  name: 'filesync'
  parent: fileService
  properties: {
    shareQuota: 100 //This is GB
    enabledProtocols: 'SMB'
  }
}

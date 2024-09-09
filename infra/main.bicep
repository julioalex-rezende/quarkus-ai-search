targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Name of the resource group')
param resourceGroupName string = ''

@description('ID of the principal')
// MS tenant: '46ef6def-8b4b-4d31-92f8-8cc3afc22644'
// BMW tenant: 'b80bb7ea-4724-4a4e-a7a4-5b2ceee60107'
param principalId string

@description('Type of the principal.')
param principalType string = 'Group'

@description('Name of the Azure Key Vault')
param keyVaultName string = ''

@description('Name of the Storage Account')
param storageAccountName string = ''

@description('Name of the storage container. Default: data')
param storageContainerName string = 'data'

@description('Location of the resource group for the storage account')
param storageResourceGroupLocation string = location

//@description('User password for SQL DB')
//@secure()
//param sqlUserPassword string

//@description('Admin password for SQL DB')
//@secure()
//param sqlAdminPassword string

@description('Capacity of the embedding deployment. Default: 30')
param embeddingDeploymentCapacity int = 240

@description('Name of the embedding model. Default: text-embedding-ada-002')
param azureEmbeddingModelName string = 'text-embedding-ada-002'

@description('SKU name for the OpenAI service. Default: S0')
param openAiSkuName string = 'S0'

@description('Name of the search index. Default: cobraidx')
param searchIndexName string = 'cobraidx'

@description('Location of the resource group for the Azure Cognitive Search service')
param searchServiceResourceGroupLocation string = location

@description('SKU name for the Azure Cognitive Search service. Default: standard')
param searchServiceSkuName string = 'standard'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// tags that should be applied to all resources.
var tags = {
  'azd-env-name': environmentName
}

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// KeyVault to store secrets
module keyVault 'core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

module keyVaultSecrets 'core/security/keyvault-secrets.bicep' = {
  scope: resourceGroup
  name: 'keyvault-secrets'
  params: {
    keyVaultName: keyVault.outputs.name
    tags: tags
    secrets: [
      {
        name: 'AzureSearchServiceEndpoint'
        value: searchService.outputs.endpoint
      }
      {
        name: 'AzureSearchIndex'
        value: searchIndexName
      }
      {
        name: 'AzureOpenAiServiceEndpoint'
        value: azureOpenAi.outputs.endpoint
      }
      {
        name: 'AzureOpenAiEmbeddingDeployment'
        value: azureEmbeddingModelName
      }
      {
        name: 'AzureStorageAccountEndpoint'
        value: storage.outputs.primaryEndpoints.blob
      }
      {
        name: 'AzureStorageContainer'
        value: storageContainerName
      }
    ]
  }
}

// Azure SQL (not used as we work with a local SQL lite DB)
//module sqlServer 'core/database/sqlserver/sqlserver.bicep' = {
//  scope: resourceGroup
//  name: '${abbrs.sqlServers}${resourceToken}'
//  params: {
//    tags: tags
//    keyVaultName: keyVault.outputs.name
//    name: '${abbrs.sqlServers}${resourceToken}'
//    databaseName: '${abbrs.sqlServersDatabases}${resourceToken}'
//    appUserPassword: sqlUserPassword
//    sqlAdminPassword: sqlAdminPassword
//  }
//}

// Storage account to store source data
module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    tags: tags
    publicNetworkAccess: 'Enabled'
    sku: {
      name: 'Standard_LRS'
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: storageContainerName
        publicAccess: 'None'
      }
    ]
  }
}

// Open AI embeddings
module azureOpenAi 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: concat([
      {
        name: azureEmbeddingModelName
        model: {
          format: 'OpenAI'
          name: azureEmbeddingModelName
          version: '2'
        }
        sku: {
          name: 'Standard'
          capacity: embeddingDeploymentCapacity
        }
      }
    ])
  }
}

// Azure AI Search
module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: resourceGroup
  params: {
    name: 'cobraais-${resourceToken}'
    location: searchServiceResourceGroupLocation
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: 'standard'
  }
}

// User Roles
module resourceGroupContributor 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'rg-role-contributor'
  params: {
    principalId: principalId
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
    principalType: principalType
  }
}

module storageRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'storage-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    principalType: principalType
  }
}

module storageContribRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'storage-contribrole-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: principalType
  }
}

module azureOpenAiRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: principalType
  }
}

module azureOpenAiRoleSearch 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'openai-role-search'
  params: {
    principalId: searchService.outputs.principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}

module searchRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'search-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
    principalType: principalType
  }
}

module searchContribRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'search-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: principalType
  }
}

module searchSvcContribRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'search-svccontrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
    principalType: principalType
  }
}

// Get subscription level role for listing deployments
// This role gives principalId group read access to the subscription
// so that others can refresh their env using azd env refresh
param roleDefinitionId string = 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader role definition ID

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup.id, principalId, roleDefinitionId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
  }
}

// Add outputs from the deployment here
// Secrets should not be added here.
// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_KEY_VAULT_RESOURCE_GROUP string = resourceGroup.name
output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_BLOB_ENDPOINT string = storage.outputs.primaryEndpoints.blob
output AZURE_STORAGE_CONTAINER string = storageContainerName
output AZURE_STORAGE_RESOURCE_GROUP string = resourceGroup.name
output AZURE_SEARCH_INDEX string = searchIndexName
output AZURE_SEARCH_SERVICE string = searchService.outputs.name
output AZURE_SEARCH_SERVICE_ENDPOINT string = searchService.outputs.endpoint
output AZURE_SEARCH_SERVICE_RESOURCE_GROUP string = resourceGroup.name
output AZURE_OPENAI_SERVICE string = azureOpenAi.outputs.name
output AZURE_OPENAI_ENDPOINT string = azureOpenAi.outputs.endpoint
output AZURE_OPENAI_EMBEDDING_DEPLOYMENT string = azureEmbeddingModelName
output AZURE_OPENAI_EMBEDDING_MODEL_NAME string = azureEmbeddingModelName
output AZURE_OPENAI_RESOURCE_GROUP string = resourceGroup.name

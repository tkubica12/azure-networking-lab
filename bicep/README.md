# Deploy

```bash
az group create -n net -l westeurope
az bicep build -f maintemplate.bicep
az deployment group create -g net --template-file maintemplate.json
```

# Destroy

```bash
export keyvault=$(az deployment group show -n firewall -g net --query properties.outputs.keyVaultName.value -o tsv)
az keyvault delete -g net -n $keyvault 
az keyvault purge -n $keyvault 
az group delete -n net -y
```
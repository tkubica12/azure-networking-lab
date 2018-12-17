# Create Resource Group
az group create -n tomas-rg -l westeurope

# Deploy template
az group deployment create -g tomas-rg \
    --template-file ./linked/networks.json \
    --parameters namePrefix=tomas 
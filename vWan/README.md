**Work in progress**


az group create -n vwan-rg -l westeurope
az bicep build -f vwan.bicep
az deployment group create -g vwan-rg --template-file vwan.json

**Work in progress**


az group create -n vwan-rg -l centralus
az bicep build -f  .\vwan\vwan.bicep
az deployment group create -g vwan-rg --template-file .\vwan\vwan.json

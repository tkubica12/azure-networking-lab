# Create Resource Group
az group create -n networking-demo-rg -l westeurope

# Deploy template
az deployment group create -g networking-demo-rg \
    --template-file main.json \
    --parameters namePrefix=networking-demo 

# Modifying deployment parameters
## Template defaults to Azure Firewall. If you want to use 3rd party solution (Linux with iptables), specify use this:
az deployment group create -g networking-demo-rg \
    --template-file main.json \
    --parameters namePrefix=demo \
    --parameters firewallType=Appliance

## Template defaults to Azure Application Gateway. If you want to use 3rd party solution (Linux with NGINX), specify use this:
az deployment group create -g networking-demo-rg \
    --template-file main.json \
    --parameters namePrefix=demo \
    --parameters wafType=Appliance

## You can also combine the two:
az deployment group create -g networking-demo-rg \
    --template-file main.json \
    --parameters namePrefix=demo \
    --parameters wafType=Appliance \
    --parameters firewallType=Appliance

## Deploying VPNs takes about 40 minutes. If you need environment quickly and you are not interested in VPN solution, you can skip it:
az eployment group create -g networking-demo-rg \
    --template-file main.json \
    --parameters namePrefix=demo \
    --parameters deployVpn=false

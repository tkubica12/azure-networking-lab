# Create Resource Group
az group create -n tomas-rg -l westeurope

# Deploy template
az group deployment create -g tomas-rg \
    --template-file main.json \
    --parameters namePrefix=tomas 

# Modifying deployment parameters
## Template defaults to Azure Firewall. If you want to use 3rd party solution (Linux with iptables), specify use this:
az group deployment create -g tomas-rg \
    --template-file main.json \
    --parameters namePrefix=tomas \
    --parameters firewallType=Appliance

## Template defaults to Azure Application Gatewaz. If you want to use 3rd party solution (Linux with NGINX), specify use this:
az group deployment create -g tomas-rg \
    --template-file main.json \
    --parameters namePrefix=tomas \
    --parameters wafType=Appliance

## You can also combine the two:
az group deployment create -g tomas-rg \
    --template-file main.json \
    --parameters namePrefix=tomas \
    --parameters wafType=Appliance \
    --parameters firewallType=Appliance

## Deploying VPNs takes about 40 minutes. If you need environment quickly and you are not interested in VPN solution, you can skip it:
az group deployment create -g tomas-rg \
    --template-file main.json \
    --parameters namePrefix=tomas \
    --parameters deployVpn=false

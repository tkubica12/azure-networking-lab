# Introduction to Azure Networking - lab

This lab (guide.sh) will guide you throw creation of enterprise networking environment in Azure including:
* VNETs and subnets
* Hub-and-spoke topology with VNET peering
* Load balancing to different availability zones
* Network Security Groups
* Using jump server to enhance security
* VPN connectivity to on-premises
* Firewall/router to filter traffic between spokes and access Internet (Azure Firewall od 3rd party option)
* IaaS to PaaS integration via Azure Firewall or 3rd party routing/firewall (using Linux router)
* PaaS network integration with Private link
* Deploying reverse proxy (and WAF) in HA to securely expose apps to Internet using Azure Application Gateway or 3rd party solution (NGINX)
* Using ARM templates for automation
* Integrating WebApps (PaaS) with VNET
* Global application delivery with Front Door

Folow instructions in guide.sh and use your name and pod number assigned by instructor.
Instructor will use central.sh to deploy simulation of on-premises environment.

# ARM template to quickly build complete demo
If you do not want to build environment yourself step by step, but rather need to deploy complete solution in one step, use ARM templates in ArmEnv folder or click Deploy to Azure button here:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Ftkubica12%2Fazure-networking-lab%2Fraw%2Fmaster%2FArmEnv%2Fmain.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

There are couple of parameters you can use to tweek your environment such as whether you want native components such as Azure Firewall and Azure Application Gateway or deploy solution using 3rd party components (represented by Linux VMs with iptables and NGINX).

# Network diagram

![diagram](./img/diagramNative.png)

# Tests after environment is deployed
Connect to jump server on its public ip.

## Test Private DNS
```bash
dig networking-demo-app1-vm.networking-demo.cz
```

## Check you can access app1 VM only via jump server (NSG)
```bash
ssh tomas@10.0.16.8 # should work
ssh tomas@10.0.1.4 # go to hub vm
    ssh tomas@10.0.16.8 # should fail
```

## Check app1 talks to outside of VNET via firewall
```bash
ssh tomas@10.0.16.8
    curl www.microsoft.com # allowed
    curl www.google.com # denied by Azure Firewall

# or connect to 3rd party appliance (10.0.3.4) and run tcpdump to check packets going throw

curl 10.0.32.4 # check access from app1 to web1

# Test threat intelligence
curl clicnews.com # Allowed from unprotected jump, denied from App1 behind Azure Firewall

# Traceroute via firewall
sudo apt update && sudo apt install traceroute -y && sudo traceroute -T 10.0.32.4
```

## Test load balancer
```bash
curl 10.0.32.4
curl 10.0.32.5
while true; do curl 10.0.32.100; done
```

## Check web farm is exposed via reverse proxy
Obtain reverse proxy public IP (IP of App Gateway or public IP of LB in front of 3rd party VMs)

## Test IaaS to PaaS secure connection via Private Link
Make sure you are not able to access your SQL server from jump server or your laptop over Internet. SQL server name is generated and it will be different in your case:

```bash
ssh tomas@10.0.16.8 # jump to app1
dig networking-demo-dbsrv-54pvmqd6pbm7c.database.windows.net  # Check private IP is returned
sqlcmd -S networking-demo-dbsrv-54pvmqd6pbm7c.database.windows.net -U tomas -P Azure12345678
```

## Check connection to onpremises resource
from jump server
ssh tomas@10.254.0.4

## Check PaaS (App Service) to VNET integration
Open globalwebregion1 WebApp and click on console
From PaaS check connectivity to VMs in VNET:
tcpping 10.0.0.4:22

## Check Azure Front Door
Get front door FQDN and test connectivity to WebApp

Try access with SQL injection attempt
https://networking-demo-globalniweb.azurefd.net/?%3D%27or%201%3D1

Access from jump server multiple times - no rate limit is applied.
```bash
curl https://networking-demo-globalniweb.azurefd.net
```

Access from PC in Czech Republic multiple times - you will be rate limited.
https://networking-demo-globalniweb.azurefd.net

To test routing rules try put word "super" to URL. You will be redirected to Microsoft main page.
https://networking-demo-globalniweb.azurefd.net?super

Check global distribution - measure connection time from your PC, from jump server or other locations.

Via Front Door:
curl -w "Lookup: %{time_namelookup} \nConnect:%{time_connect} \n" http://networking-demo-globalniweb.azurefd.net --output /dev/null -s

Directly to WebApp in West Europe:
curl -w "Lookup: %{time_namelookup} \nConnect:%{time_connect} \n" https://networking-demo-globalwebregion1.azurewebsites.net --output /dev/null -s
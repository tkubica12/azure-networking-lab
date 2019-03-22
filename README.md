# Introduction to Azure Networking - lab

This lab (guide.sh) will guide you throw creation of enterprise networking environment in Azure including:
* VNETs and subnets
* Hub-and-spoke topology with VNET peering
* Load balancing
* Network Security Groups
* Using jump server to enhance security
* VPN connectivity to on-premises
* Firewall/router to filter traffic between spokes and access Internet (Azure Firewall od 3rd party option)
* IaaS to PaaS integration via Azure Firewall or 3rd party routing/firewall (using Linux router)
* IaaS to PaaS direct integration via Service Endpoints
* Deploying reverse proxy (and WAF) in HA to securely expose apps to Internet using Azure Application Gateway or 3rd party solution (NGINX)
* Using ARM templates for automation

Folow instructions in guide.sh and use your name and pod number assigned by instructor.
Instructor will use central.sh to deploy simulation of on-premises environment.

# ARM template to quickly build complete demo
If you do not want to build environment yourself step by step, but rather need to deploy complete solution in one step, use ARM templates in ArmEnv folder or click Deploy to Azure button here:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fgithub.com%2Ftkubica12%2Fazure-networking-lab%2Fraw%2Fmaster%2FArmEnv%2Fmain.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

There are couple of parameters you can use to tweek your environment such as whether you want native components such as Azure Firewall and Azure Application Gateway or deploy solution using 3rd party components (represented by Linux VMs with iptables and NGINX).

# Network diagram

![diagram](./img/diagram.png)
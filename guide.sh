# Get your lab pod number and store it together with your name
export podNumber=1
export podName=tomas

# ------------ Basic routing and VNET peering ------------
# Create Resource Group
az group create -n $podName-rg -l westeurope

# Create VNET and subnets
az network vnet create -g $podName-rg -n $podName-hub-net --address-prefix 10.$podNumber.0.0/20

az network vnet subnet create -g $podName-rg --vnet-name $podName-hub-net \
    -n jumpserver-sub --address-prefix 10.$podNumber.0.0/24
az network vnet subnet create -g $podName-rg --vnet-name $podName-hub-net \
    -n sharedservices-sub --address-prefix 10.$podNumber.1.0/24
az network vnet subnet create -g $podName-rg --vnet-name $podName-hub-net \
    -n GatewaySubnet --address-prefix 10.$podNumber.2.0/24

# Create gateway device (VPN GW or ER GW if you have circuit available)
az network public-ip create -n $podName-vpn-ip -g $podName-rg
az network vnet-gateway create -g $podName-rg -n $podName-vpn \
    --public-ip-address $podName-vpn-ip --vnet $podName-hub-net \
    --gateway-type Vpn --sku Basic --no-wait

# Create jump server
az vm create -n $podName-jump-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --vnet-name $podName-hub-net \
    --subnet jumpserver-sub \
    --storage-sku Standard_LRS

# Create additinal server
az vm create -n $podName-hub-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --vnet-name $podName-hub-net \
    --subnet sharedservices-sub \
    --storage-sku Standard_LRS \
    --no-wait

# Make sure you can connect to jump server
az vm list-ip-addresses -g $podName-rg -o table
export jump=$(az vm list-ip-addresses -g $podName-rg -n $podName-jump-vm --query [].virtualMachine.network.publicIpAddresses[].ipAddress -o tsv)
ssh tomas@$jump

# Create two spoke VNETs and subnets
az network vnet create -g $podName-rg -n $podName-spoke1-net --address-prefix 10.$podNumber.16.0/20
az network vnet create -g $podName-rg -n $podName-spoke2-net --address-prefix 10.$podNumber.32.0/20

az network vnet subnet create -g $podName-rg --vnet-name $podName-spoke1-net \
    -n sub1 --address-prefix 10.$podNumber.16.0/24
az network vnet subnet create -g $podName-rg --vnet-name $podName-spoke1-net \
    -n sub2 --address-prefix 10.$podNumber.17.0/24
az network vnet subnet create -g $podName-rg --vnet-name $podName-spoke2-net \
    -n sub1 --address-prefix 10.$podNumber.32.0/24
az network vnet subnet create -g $podName-rg --vnet-name $podName-spoke2-net \
    -n sub2 --address-prefix 10.$podNumber.33.0/24

# Create app server in spoke1
az vm create -n $podName-app1-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --vnet-name $podName-spoke1-net \
    --subnet sub1 \
    --storage-sku Standard_LRS

# Check effective routes - app1 cannot talk to jump server, VNETs are not peered
az vm show --name $podName-app1-vm --resource-group $podName-rg    # You can get VM details including NIC name
az network nic show-effective-route-table --name $podName-jump-vmVMNic --resource-group $podName-rg -o table

# Configure VNET peering in hub-and-spoke topology
az network vnet peering create -g $podName-rg -n hub-to-spoke1 \
    --vnet-name $podName-hub-net --remote-vnet $podName-spoke1-net \
    --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
az network vnet peering create -g $podName-rg -n hub-to-spoke2 \
    --vnet-name $podName-hub-net --remote-vnet $podName-spoke2-net \
    --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
az network vnet peering create -g $podName-rg -n spoke1-to-hub \
    --vnet-name $podName-spoke1-net --remote-vnet $podName-hub-net \
    --allow-vnet-access --allow-forwarded-traffic --use-remote-gateways
az network vnet peering create -g $podName-rg -n spoke2-to-hub \
    --vnet-name $podName-spoke2-net --remote-vnet $podName-hub-net \
    --allow-vnet-access --allow-forwarded-traffic --use-remote-gateways

# Check effective routes now, connect to app1 from jump server to check routing is OK
az network nic show-effective-route-table --name $podName-jump-vmVMNic --resource-group $podName-rg -o table

# ------------ Adding Network Security Groups ------------

# We are going to create servers in spoke2. 
# We will prepare FW rules (NSG) on subnet to permit only web(80) inbound, but ssh(22) only from jump server
az network nsg create -g $podName-rg -n $podName-spoke2-sub1-fw

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke2-sub1-fw \
    -n allowSSHFromJump --priority 100 \
    --source-address-prefixes 10.$podNumber.0.4/32 --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow \
    --protocol Tcp --description "Allow SSH traffic from jump server"

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke2-sub1-fw \
    -n denySSH --priority 105 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 22 --access Deny \
    --protocol Tcp --description "Deny SSH traffic"

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke2-sub1-fw \
    -n allowWeb --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 80 443 --access Allow \
    --protocol Tcp --description "Allow WEB traffic"

az network vnet subnet update -g $podName-rg -n sub1 \
    --vnet-name $podName-spoke2-net --network-security-group $podName-spoke2-sub1-fw

# Create web server farm in HA deployed in two availability zones in spoke2 network
az vm create -n $podName-web1-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --zone 1 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --vnet-name $podName-spoke2-net \
    --subnet sub1 \
    --storage-sku Standard_LRS \
    --no-wait

az vm create -n $podName-web2-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --zone 2 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --vnet-name $podName-spoke2-net \
    --subnet sub1 \
    --storage-sku Standard_LRS \
    --no-wait

# List effective FW rules on web1 NIC
az network nic list-effective-nsg -g $podName-rg -n tomas-web1-vmVMNic

# Check NSGs are working. SSH from jump server - should work. 
# On servers install Apache web service
az vm list-ip-addresses -g $podName-rg -o table
ssh tomas@$jump
    ssh tomas@10.x.32.4
        sudo apt update && sudo apt install apache2 -y   # Install web server
        echo "Server 1 is alive!" | sudo tee /var/www/html/index.html  # Change default page
        curl 127.0.0.1   # Check web works
        exit
    ssh tomas@10.x.32.5
        sudo apt update && sudo apt install apache2 -y   # Install web server
        echo "Server 2 is alive!" | sudo tee /var/www/html/index.html  # Change default page
        curl 127.0.0.1   # Check web works
        exit

# SSH from jump to share vm server
# From there SSH to web1 (should fail) and run curl to web1 (should be ok)
ssh tomas@$jump
    ssh tomas@10.x.1.4
        ssh tomas@10.x.32.4  # Should fail
        curl 10.x.32.4   # Should work

# ------------ Using Azure Load Balancer ------------

# Create Azure Load Balancer Standard and configure it for internal balancer
# We will not use any session persistence so we can easily check balancing is working
## Create LB with private IP and backend pool
az network lb create -g $podName-rg -n $podName-web-lb --sku Standard --backend-pool-name web-pool \
    --vnet-name $podName-spoke2-net --subnet sub1 --private-ip-address 10.$podNumber.32.100
## Add NICs to pool
az network nic ip-config address-pool add -g $podName-rg \
    --nic-name $podName-web1-vmVMNic -n ipconfig$podName-web1-vm \
    --address-pool web-pool --lb-name $podName-web-lb
az network nic ip-config address-pool add -g $podName-rg \
    --nic-name $podName-web2-vmVMNic -n ipconfig$podName-web2-vm \
    --address-pool web-pool --lb-name $podName-web-lb
## Configure health probe
az network lb probe create --resource-group $podName-rg \
    --lb-name $podName-web-lb --name myHealthProbe \
    --protocol tcp --port 80
## Add LB rules
az network lb rule create --resource-group $podName-rg \
    --lb-name $podName-web-lb --name myHTTPRule \
    --protocol tcp --frontend-port 80 --backend-port 80 \
    --frontend-ip-name LoadBalancerFrontEnd \
    --backend-pool-name web-pool \
    --probe-name myHealthProbe

# Go to jump server and test balancing
ssh tomas@jump
    while true; do curl 10.1.32.100; done

# Check how traffic looks on web1 server (open in new session window)
# You should see health probes comming from 168.63.129.16
# Also you should see web traffic directly to client (jump server) on 10.x.0.4
ssh tomas@jump
    ssh tomas@10.1.32.4
        sudo tcpdump port 80 

# ------------ Connecting onpremises with VPN ------------

# Configure VPN gateway to connect to on-premises environment and check routing
export onpremVpnIp="137.117.230.128"
az network local-gateway create --gateway-ip-address $onpremVpnIp \
    --name $podName-onprem --resource-group $podName-rg \
    --local-address-prefixes 10.254.0.0/16
az network vpn-connection create --name $podName-to-onprem \
    --resource-group $podName-rg --vnet-gateway1 $podName-vpn \
    -l westeurope --shared-key Azure12345678 --local-gateway2 $podName-onprem

# Check app1 can access onprem VM and check app1 effective routes
ssh tomas@jump
    ssh tomas@10.x.16.4
        ping 10.254.0.4

az network nic show-effective-route-table --name $podName-app1-vmVMNic --resource-group $podName-rg -o table

# ------------ Network Virtual Appliance ------------

# Note spoke1 cannot talk to spoke2 currently
# Create network virtual appliance (we will use Linux box) to enable routing and inspection of selected traffic and provide Internet connectivity
## Create appliance subnet and Linux VM. We will create NIC before so we can enable IP forwarding (ability to receive traffic not targeted to VM itself)
az network vnet subnet create -g $podName-rg --vnet-name $podName-hub-net \
    -n ngfw-int --address-prefix 10.$podNumber.3.0/26
az network nic create -g $podName-rg --vnet-name $podName-hub-net \
    --subnet ngfw-int -n $podName-ngfw-nic --ip-forwarding
az vm create -n $podName-ngfw-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nics $podName-ngfw-nic \
    --storage-sku Standard_LRS \
    --no-wait

## Configure Linux box as router and start tcpdump for host app1
ssh tomas@$jump
    ssh tomas@10.x.3.4
        sudo ufw disable
        sudo sysctl -w net.ipv4.ip_forward=1
        echo net.ipv4.ip_forward = 1 | sudo tee /etc/sysctl.conf
        sudo tcpdump host 10.x.16.4  # We should not see any traffic

## Configure routing rule from spoke1/sub1 with your Linux box as next hop (service insertion)
az network route-table create -g $podName-rg -n $podName-routes
az network route-table route create -g $podName-rg --route-table-name $podName-routes \
    -n toNGFW --next-hop-type VirtualAppliance \
    --address-prefix 0.0.0.0/0 --next-hop-ip-address 10.$podNumber.3.4
az network vnet subnet update -g $podName-rg -n sub1 \
    --vnet-name $podName-spoke1-net --route-table $podName-routes

## Connect to app1 via jump server in new session
## Ping 10.x.32.100 - does not work. Look into tcpdump on Linux router. 
## You should see packets comming in, but no response comming back.
## Configure service insertion also on web subnet
az network vnet subnet update -g $podName-rg -n sub1 \
    --vnet-name $podName-spoke2-net --route-table $podName-routes

## Test curl from app1 to web lb again. Should work now.

## Test ping to onprem from app1 - it should work.
## Nevertheless check effective routes on app1 - it currently goes directly bypassing Linux router
ssh tomas@jump
    ssh tomas@10.x.16.4
        ping 10.254.0.4

az network nic show-effective-route-table --name $podName-app1-vmVMNic --resource-group $podName-rg -o table

## We will now want traffic between app1 and onprem to be inspected by Linux router.
## As route to 10.254.0.0/16 via GW directly is more specific we need to add our own route for this range via Linux router
az network route-table route create -g $podName-rg --route-table-name $podName-routes \
    -n toOnpremViaNGFW --next-hop-type VirtualAppliance \
    --address-prefix 10.254.0.0/16 --next-hop-ip-address 10.$podNumber.3.4
ssh tomas@jump
    ssh tomas@10.x.16.4
        ping 10.254.0.4

az network nic show-effective-route-table --name $podName-app1-vmVMNic --resource-group $podName-rg -o table

## Go to Linux router and do sudo tcpdump icmp. We see packets only in one direction!
## Returning traffic should not go directly so we need to modify routing on GatewaySubnet in hub network
az network route-table create -g $podName-rg -n $podName-gwRoutes
az network route-table route create -g $podName-rg --route-table-name $podName-gwRoutes \
    -n toNGFW --next-hop-type VirtualAppliance \
    --address-prefix 10.$podNumber.16.0/24 --next-hop-ip-address 10.$podNumber.3.4
az network vnet subnet update -g $podName-rg -n GatewaySubnet \
    --vnet-name $podName-hub-net --route-table $podName-gwRoutes

# ------------ Monitoring and troubleshooting ------------

# Monitoring and troubleshooting
## Prepare storage account and log analytics workspace
## Use Azure Monitor to do packet capture
## Configure logging to storage account for load balancer and NSGs
## Turn on Traffic Analyses in Azure Monitor
## Configure Connection Monitor

# ------------ Internet access via Network Virtual Appliance ------------

# Enhance our Linux router to provide access to Internet. 
## First turn of VM
az vm deallocate -n $podName-ngfw-vm -g $podName-rg

## Create additional subnet, NIC, public IP, associate with NIC and attach to VM and start
az network vnet subnet create -g $podName-rg --vnet-name $podName-hub-net \
    -n ngfw-ext --address-prefix 10.$podNumber.3.64/26
az network public-ip create -n $podName-ngfw-ip -g $podName-rg
az network nic create -g $podName-rg --vnet-name $podName-hub-net \
    --subnet ngfw-ext -n $podName-ngfw-nic-ext --ip-forwarding \
    --public-ip-address $podName-ngfw-ip
az vm nic add -g $podName-rg --vm-name $podName-ngfw-vm \
    --nics $podName-ngfw-nic-ext
az vm start -n $podName-ngfw-vm -g $podName-rg

## Configure Linux router for NAT via iptables and modify its routing rules
ssh tomas@$jump
    ssh tomas@10.x.3.4
        sudo ip route add 10.0.0.0/8 via 10.1.3.1 dev eth0
        sudo ip route change 0.0.0.0/0 via 10.1.3.65 dev eth1
        sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
        sudo iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        sudo iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
        echo sudo ip route add 10.0.0.0/8 via 10.1.3.1 dev eth0 | sudo tee /etc/rc.local
        echo sudo ip route change 0.0.0.0/0 via 10.1.3.65 dev eth1 | sudo tee /etc/rc.local
        echo sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE | sudo tee /etc/rc.local
        echo sudo iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT | sudo tee /etc/rc.local
        echo sudo iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT | sudo tee /etc/rc.local

## Check connectivity from app1 to Internet - should work
## Use tcpdump on Linux router to make sure traffic goes via this device

# ------------ Connecting to PaaS services ------------

# PaaS services such as SQL network integration
## PaaS integration via Network Virtual Appliance
### Create small Azure SQL Database
az sql server create -l westeurope -g $podName-rg \
    -n $podName-db-srv -u tomas -p Azure12345678
az sql db create -g $podName-rg -s $podName-db-srv \
    -n $podName-db --service-objective Basic --edition Basic

### Install SqlCmd utility on app1 server. User access to DB should fail since there is no whitelist on DB firewall.
ssh tomas@$jump
    ssh tomas@10.x.16.4
        curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
        curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
        sudo apt-get update 
        sudo apt-get install mssql-tools unixodbc-dev -y
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
        source ~/.bashrc
        sqlcmd -S tomas-db-srv.database.windows.net -U tomas -P Azure12345678  # Should fail, not src IP is your Linux router (NGFW) IP

### Configure DB firewall to allow access from NGFW only and make sure app1 can communicate.
export ngfwIp=$(az network public-ip show -n tomas-ngfw-ip -g $podName-rg --query ipAddress -o tsv)
az sql server firewall-rule create -g $podName-rg \
    -s $podName-db-srv -n allowNgfw \
    --start-ip-address $ngfwIp --end-ip-address $ngfwIp

### Check again access from app1
ssh tomas@$jump
    ssh tomas@10.x.16.4
        sqlcmd -S tomas-db-srv.database.windows.net -U tomas -P Azure12345678  # Should work

## Direct PaaS integration via Service Endpoint
### Remove Linux router IP from DB firewall
az sql server firewall-rule delete -g $podName-rg -s $podName-db-srv -n allowNgfw

### Check again access from app1
ssh tomas@$jump
    ssh tomas@10.x.16.4
        sqlcmd -S tomas-db-srv.database.windows.net -U tomas -P Azure12345678  # Should fail

### Configure direct link between subnet and PaaS with Service Endpoint
az network vnet subnet update -g $podName-rg --vnet-name $podName-spoke1-net \
    -n sub1 --service-endpoints Microsoft.Sql
az sql server vnet-rule create -g $podName-rg -s $podName-db-srv \
    -n linkForSQL --subnet sub1 --vnet-name $podName-spoke1-net

### Check again access from app1
ssh tomas@$jump
    ssh tomas@10.x.16.4
        sqlcmd -S tomas-db-srv.database.windows.net -U tomas -P Azure12345678  # Should work

### Limit app1 access to Internet while preserving access to PaaS service
az network nsg create -g $podName-rg -n $podName-spoke1-sub1-fw

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke1-sub1-fw \
    -n allowSSHFromJump --priority 100 \
    --source-address-prefixes 10.$podNumber.0.4/32 --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow \
    --protocol Tcp --description "Allow SSH traffic from jump server"

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke1-sub1-fw \
    -n denySSH --priority 105 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 22 --access Deny \
    --protocol Tcp --description "Deny SSH traffic"

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke1-sub1-fw \
    -n allowPaasSql --priority 100 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes Sql.WestEurope --destination-port-ranges 1433 \
    --access Allow --direction Outbound \
    --protocol Tcp --description "Allow PaaS SQL traffic"

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke1-sub1-fw \
    -n denyInternet --priority 105 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes Internet --destination-port-ranges '*' \
    --access Deny --direction Outbound \
    --protocol '*' --description "Disable access to Internet"

az network vnet subnet update -g $podName-rg -n sub1 \
    --vnet-name $podName-spoke1-net --network-security-group $podName-spoke1-sub1-fw

## Direct PaaS integration via private PaaS endpoint (preview feature)
TODO

# ------------ Exposing apps to Internet via reverse proxy ------------

# Expose web application to internet via reverse proxy appliance (we will use NGINX, but F5 or Imperva is conceptualy similar)
# Use redundant pair of reverse proxy together with one internal and one external Azure Load Balancer
## Create additional subnet for reverse proxy
az network vnet subnet create -g $podName-rg --vnet-name $podName-hub-net \
    -n rp --address-prefix 10.$podNumber.3.128/26

## Prepare NSG to allow traffic from Internet to reverse proxy
az network nsg create -g $podName-rg -n $podName-hub-rp-fw

az network nsg rule create -g $podName-rg --nsg-name $podName-spoke1-sub1-fw \
    -n allowSSHFromJump --priority 100 \
    --source-address-prefixes 10.$podNumber.0.4/32 --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow \
    --protocol Tcp --description "Allow SSH traffic from jump server"

az network nsg rule create -g $podName-rg --nsg-name $podName-hub-rp-fw \
    -n allowInternetAccess --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 8080-8090 --access Allow \
    --protocol Tcp --description "Allow access from Internet to reverse proxy ports"

## Create reverse proxy NVAs in hub network
az vm create -n $podName-rp1-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --zone 1 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg $podName-hub-rp-fw \
    --public-ip-address "" \
    --vnet-name $podName-hub-net \
    --subnet rp \
    --storage-sku Standard_LRS \
    --no-wait

az vm create -n $podName-rp2-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --zone 2 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg $podName-hub-rp-fw \
    --public-ip-address "" \
    --vnet-name $podName-hub-net \
    --subnet rp \
    --storage-sku Standard_LRS \
    --no-wait

## Create Azure Load Balancer with public IP and configure rules and pools
az network public-ip create -g $podName-rg -n $podName-rp-ip \
    --dns-name $podName-wapp998 --sku Standard

az network lb create -g $podName-rg -n $podName-rp-lb --sku Standard \
    --backend-pool-name rp-pool --public-ip-address $podName-rp-ip 

az network lb probe create --resource-group $podName-rg \
    --lb-name $podName-rp-lb --name myHealthProbe \
    --protocol tcp --port 8080

az network lb rule create --resource-group $podName-rg \
    --lb-name $podName-rp-lb --name app1 \
    --protocol tcp --frontend-port 80 --backend-port 8080 \
    --frontend-ip-name LoadBalancerFrontEnd \
    --backend-pool-name rp-pool \
    --probe-name myHealthProbe

az network nic ip-config address-pool add -g $podName-rg \
    --nic-name $podName-rp1-vmVMNic -n ipconfig$podName-rp1-vm \
    --address-pool rp-pool --lb-name $podName-rp-lb
az network nic ip-config address-pool add -g $podName-rg \
    --nic-name $podName-rp2-vmVMNic -n ipconfig$podName-rp2-vm \
    --address-pool rp-pool --lb-name $podName-rp-lb

## Install and configure NGINX on both NVAs
## Note we will use server_name as DNS entry we configured for LB NIC.
## This way you can create multiple records on your DNS server (such as Azure DNS)
## and host unlimited number of applications on single frontend IP and RP port.
## With TLS you will use SNI to enable that (certificate per app as an example)
## Nevertheless you can also add additional Public IP on Azure LB and create rule to point
## to different RP port such as 8081. This way you can for example have 2 apps
## running on different public IPs.
ssh tomas@$jump
    ssh tomas@10.x.3.132
        sudo apt update && sudo apt install nginx -y
        sudo nano /etc/nginx/conf.d/myapp.conf  # Use following configuration - replace name with your name and proxy_pass with your webapp LB IP

server {
  listen 8080;

  server_name tomas-wapp998.westeurope.cloudapp.azure.com;

  location / {
      proxy_pass http://10.x.32.100/;
  }
}



        sudo nginx -s reload

# Repeat for second NGINX (10.x.3.132)
# Use your browser to open $podName-wapp998.westeurope.cloudapp.azure.com - should work

# ------------ Automation (Infrastructure as Code) ------------

# Automate environment using desired state Azure Resource Manager templates
az group create -n $podName-new-rg -l westeurope
## New Hub VNET and subnets
az group deployment create -g $podName-new-rg \
    --template-file 01net.json --parameters @01net.parameters.json
## Add spoke networks to template
az group deployment create -g $podName-new-rg \
    --template-file 02net.json --parameters @02net.parameters.json
## Add VNET peerings to template
az group deployment create -g $podName-new-rg \
    --template-file 03net.json --parameters @03net.parameters.json

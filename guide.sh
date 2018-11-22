# Get your lab pod number and store it together with your name
export podNumber=1
export podName=tomas

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

# Configure VPN gateway to connect to on-premises environment and check routing

# Note spoke1 cannot talk to spoke2 currently
# Create network virtual appliance (we will use Linux box) to enable routing and inspection of selected traffic and provide Internet connectivity

# Configure sub1 in spoke1 and sub1 in spoke2 to get inspected by network appliance (such as NGFW)

# Configure solution to put network appliance (such as NGFW) between VPN gateway and some Azure subnets

# Expose web application to internet via reverse proxy appliance (we will use NGINX, but F5 or Imperva is conceptualy similar)
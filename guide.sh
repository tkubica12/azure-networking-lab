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

# We are going to create servers in spoke2. We will prepare FW rules (NSG) on subnet to permit only web(80) inbound, but ssh(22) only from jump server

# Create web server farm in HA deployed in two availability zones in spoke2 network
az vm create -n $podName-web1-vm \
    -g $podName-rg \
    --image ubuntults \
    --size Standard_B1s \
    --zone 1 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg $podName-web1-fw \
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
    --nsg $podName-web2-fw \
    --public-ip-address "" \
    --vnet-name $podName-spoke2-net \
    --subnet sub1 \
    --storage-sku Standard_LRS \
    --no-wait

# Check NSGs are working. SSH from jump server - should work. 
# SSH from jump to app1 and from there SSH to web1 (should fail) and run curl to web1 (should be ok)

# Install web servers (SSH from jump server)

# Create Azure Load Balancer Standard and configure it for internal balancer

# Configure VPN gateway to connect to on-premises environment and check routing


# Create network virtual appliance (we will use Linux box) to enable inspection of selected traffic and provide Internet connectivity

# Configure sub1 in spoke1 and sub1 in spoke2 to get inspected by network appliance (such as NGFW)

# Configure solution to put network appliance (such as NGFW) between VPN gateway and some Azure subnets

# Expose web application to internet via reverse proxy appliance (we will use NGINX, but F5 or Imperva is conceptualy similar)
az group create -n central-rg -l centralus
az network vnet create -g central-rg -n central-net --address-prefix 10.254.0.0/16

az network vnet subnet create -g central-rg --vnet-name central-net \
    -n server-sub --address-prefix 10.254.0.0/24
az network vnet subnet create -g central-rg --vnet-name central-net \
    -n GatewaySubnet --address-prefix 10.254.1.0/24

az network public-ip create -n central-vpn-ip -g central-rg
az network vnet-gateway create -g central-rg -n central-vpn \
    --public-ip-address central-vpn-ip --vnet central-net \
    --gateway-type Vpn --sku VpnGw1 --no-wait

az vm create -n central-vm \
    -g central-rg \
    --image ubuntults \
    --size Standard_B1s \
    --admin-username demouser \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --vnet-name central-net \
    --subnet server-sub \
    --storage-sku Standard_LRS \
    --no-wait

az network public-ip show -n central-vpn-ip -g central-rg

export vpnIp1="23.97.175.85"
export vpnRange1="10.1.0.0/16"
az network local-gateway create --gateway-ip-address $vpnIp1 \
    --name central-$vpnIp1 --resource-group central-rg \
    --local-address-prefixes $vpnRange1
az network vpn-connection create --name central-to-$vpnIp1 \
    --resource-group central-rg --vnet-gateway1 central-vpn \
    -l centralus --shared-key Azure12345678 --local-gateway2 central-$vpnIp1
# Route Server
In this demo we will use Route Server to provide dynamic routing control plane between NVA (we will use Linux machine with Quagga) and Azure so routing in Azure is programmed automatically (as opposed to UDRs) and routing table of Azure is learned by NVA.

Create hub network

```bash
export rg=route-server-test-rg
az group create -n $rg -l centralus
az network vnet create -n hub-net -g $rg --address-prefixes 10.0.0.0/16
az network vnet subnet create -n RouteServerSubnet -g $rg --vnet-name hub-net --address-prefixes 10.0.0.0/24
az network vnet subnet create -n NvaSubnet -g $rg --vnet-name hub-net --address-prefixes 10.0.1.0/24
az network vnet subnet create -n VmSubnet -g $rg --vnet-name hub-net --address-prefixes 10.0.2.0/24
```

Create Route Server

```bash
az network routeserver create -n route-server -g $rg \
    --hosted-subnet $(az network vnet subnet show -n RouteServerSubnet -g $rg --vnet-name hub-net --query id -o tsv)
```


Note Route Server IP and BGP ASN

```bash
az network routeserver show -n route-server -g $rg --query virtualRouterAsn -o tsv
az network routeserver show -n route-server -g $rg --query virtualRouterIps -o tsv
```

Create NVA by provisioning Ubuntu VM

```bash
az vm create -n linux-nva \
    -g $rg \
    --image UbuntuLTS \
    --size Standard_B1ms \
    --zone 1 \
    --admin-username tomas \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --public-ip-address nva-ip \
    --subnet NvaSubnet \
    --vnet-name hub-net \
    --storage-sku Standard_LRS
```

Configure NVA as peer in Route Server

```bash
az network routeserver peering create --routeserver route-server -g $rg --peer-ip 10.0.1.4 --peer-asn 65514 -n nva1
```

Install Quagga and configure

```bash
ssh tomas@$(az network public-ip show -n nva-ip -g $rg --query ipAddress -o tsv)
    sudo -i
    apt update
    apt install quagga quagga-doc -y
    sysctl -w net.ipv4.ip_forward=1
    cat > /etc/quagga/zebra.conf << EOF
hostname Router
password zebra
enable password zebra
interface eth0
interface lo
ip forwarding
line vty
EOF
    cat > /etc/quagga/vtysh.conf << EOF
!service integrated-vtysh-config
hostname quagga-router
username root nopassword
EOF
    cat > /etc/quagga/bgpd.conf << EOF
hostname bgpd
password zebra
enable password zebra
router bgp 65514
network 10.50.0.0/16
network 10.60.0.0/16
network 10.70.0.0/16
neighbor 10.0.0.4 remote-as 65515
neighbor 10.0.0.4 soft-reconfiguration inbound
neighbor 10.0.0.5 remote-as 65515
neighbor 10.0.0.5 soft-reconfiguration inbound
line vty
EOF
    chown quagga:quagga /etc/quagga/*.conf
    chown quagga:quaggavty /etc/quagga/vtysh.conf
    chmod 640 /etc/quagga/*.conf
    echo 'zebra=yes' > /etc/quagga/daemons
    echo 'bgpd=yes' >> /etc/quagga/daemons
    systemctl enable zebra.service
    systemctl enable bgpd.service
    systemctl start zebra 
    systemctl start bgpd  
```

See how Route Server learned routes from NVA and pushed it to NICs

```bash
az network routeserver peering list-advertised-routes -g $rg --routeserver route-server -n nva1
az network routeserver peering list-learned-routes -g $rg --routeserver route-server -n nva1
az network nic show-effective-route-table -g $rg -n linux-nvaVMNic -o table
```

Let's add some spoke networks, peer it to hub and make sure NVA routes propagate (Use remote gateways)

```bash
az network vnet create -n spoke1-net -g $rg --address-prefixes 10.1.0.0/16 --subnet-name sub1 --subnet-prefixes 10.1.0.0/24
az network vnet create -n spoke2-net -g $rg --address-prefixes 10.2.0.0/16 --subnet-name sub1 --subnet-prefixes 10.2.0.0/24
az network vnet peering create -n hub-to-spoke1 \
    -g $rg \
    --vnet-name hub-net \
    --remote-vnet $(az network vnet show -n spoke1-net -g $rg --query id -o tsv) \
    --allow-forwarded-traffic \
    --allow-vnet-access \
    --allow-gateway-transit
az network vnet peering create -n hub-to-spoke2 \
    -g $rg \
    --vnet-name hub-net \
    --remote-vnet $(az network vnet show -n spoke2-net -g $rg --query id -o tsv) \
    --allow-forwarded-traffic \
    --allow-vnet-access \
    --allow-gateway-transit
az network vnet peering create -n spoke1-to-hub \
    -g $rg \
    --vnet-name spoke1-net \
    --remote-vnet $(az network vnet show -n hub-net -g $rg --query id -o tsv) \
    --allow-forwarded-traffic \
    --allow-vnet-access \
    --use-remote-gateways
az network vnet peering create -n spoke2-to-hub \
    -g $rg \
    --vnet-name spoke2-net \
    --remote-vnet $(az network vnet show -n hub-net -g $rg --query id -o tsv) \
    --allow-forwarded-traffic \
    --allow-vnet-access \
    --use-remote-gateways
az vm create -n linux-vm1 \
    -g $rg \
    --image UbuntuLTS \
    --size Standard_B1s \
    --zone 1 \
    --admin-username tomas \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --public-ip-address vm1-ip \
    --subnet sub1 \
    --vnet-name spoke1-net \
    --storage-sku Standard_LRS
az network nic show-effective-route-table -g $rg -n linux-vm1VMNic -o table
```

Check routes are also learned by NVA.

```bash
ssh tomas@$(az network public-ip show -n nva-ip -g $rg --query ipAddress -o tsv)
    sudo vtysh
        show ip bgp cidr-only
```

Let's create redundant setup - add second NVA in zone 2.

```bash
az network routeserver peering create --routeserver route-server -g $rg --peer-ip 10.0.1.5 --peer-asn 65514 -n nva2
az vm create -n linux-nva2 \
    -g $rg \
    --image UbuntuLTS \
    --size Standard_B1ms \
    --zone 2 \
    --admin-username tomas \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --public-ip-address nva2-ip \
    --subnet NvaSubnet \
    --vnet-name hub-net \
    --storage-sku Standard_LRS
ssh tomas@$(az network public-ip show -n nva2-ip -g $rg --query ipAddress -o tsv)
    sudo -i
    apt update
    apt install quagga quagga-doc -y
    sysctl -w net.ipv4.ip_forward=1
    cat > /etc/quagga/zebra.conf << EOF
hostname Router
password zebra
enable password zebra
interface eth0
interface lo
ip forwarding
line vty
EOF
    cat > /etc/quagga/vtysh.conf << EOF
!service integrated-vtysh-config
hostname quagga-router
username root nopassword
EOF
    cat > /etc/quagga/bgpd.conf << EOF
hostname bgpd
password zebra
enable password zebra
router bgp 65514
! bgp router-id 10.0.0.1
network 10.50.0.0/16
network 10.60.0.0/16
network 10.70.0.0/16
neighbor 10.0.0.4 remote-as 65515
neighbor 10.0.0.4 soft-reconfiguration inbound
neighbor 10.0.0.5 remote-as 65515
neighbor 10.0.0.5 soft-reconfiguration inbound
line vty
EOF
    chown quagga:quagga /etc/quagga/*.conf
    chown quagga:quaggavty /etc/quagga/vtysh.conf
    chmod 640 /etc/quagga/*.conf
    echo 'zebra=yes' > /etc/quagga/daemons
    echo 'bgpd=yes' >> /etc/quagga/daemons
    systemctl enable zebra.service
    systemctl enable bgpd.service
    systemctl start zebra 
    systemctl start bgpd  
```

Let's see how this affected routing - we should find out both NVAs are programmed and ECMP is used.

```bash
az network nic show-effective-route-table -g $rg -n linux-vm1VMNic -o table
```

We will no keep 10.50 and 10.70 to be balanced, but configure 10.60 to prefer nva1. We will do this with classic BGP AS PATH prepending.

```bash
ssh tomas@$(az network public-ip show -n nva2-ip -g $rg --query ipAddress -o tsv)
    sudo -i
    cat > /etc/quagga/bgpd.conf << EOF
hostname bgpd
password zebra
enable password zebra
router bgp 65514
network 10.50.0.0/16
network 10.60.0.0/16
network 10.70.0.0/16
neighbor 10.0.0.4 remote-as 65515
neighbor 10.0.0.4 soft-reconfiguration inbound
neighbor 10.0.0.4 route-map r60map out
neighbor 10.0.0.5 remote-as 65515
neighbor 10.0.0.5 soft-reconfiguration inbound
neighbor 10.0.0.5 route-map r60map out
line vty
!
ip prefix-list r60 seq 10 permit 10.60.0.0/16
ip prefix-list any seq 10 permit any
route-map r60map permit 10 
match ip address prefix-list r60
set as-path prepend 65514
route-map r60map permit 20 
match ip address prefix-list any
!
EOF
    systemctl restart bgpd
    exit
    exit
    exit

az network routeserver peering list-learned-routes -g $rg --routeserver route-server -n nva2
az network nic show-effective-route-table -g $rg -n linux-vm1VMNic -o table
```

Lastly suppose we want to send all traffic via NVA so we want to install default route 0.0.0.0/0. Note that Route Server will install it also on our NVA subnet which would break its Internet connectivity. Make sure you use UDR on NVA subnet with static route 0.0.0.0/0 -> Internet.

Destroy

```bash
export rg=route-server-test-rg
az network routeserver delete -n route-server -g $rg -y
az group delete -n $rg -y
```
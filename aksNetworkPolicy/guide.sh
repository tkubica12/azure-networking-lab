# Create AKS cluster
az group create -n aksnetworkpolicy -l westeurope
az network vnet create --address-prefixes 172.16.0.0/16 -n aksnet -g aksnetworkpolicy
az network vnet subnet create -n akspool1 --vnet-name aksnet -g aksnetworkpolicy --address-prefixes "172.16.0.0/24"
az aks create -n aksnetworkpolicy -x -c 1 -g aksnetworkpolicy --network-plugin azure --network-policy azure -s Standard_B2s \
    --vnet-subnet-id $(az network vnet subnet show -n akspool1 --vnet-name aksnet -g aksnetworkpolicy --query id -o tsv)

# Deploy apps
az aks get-credentials -n aksnetworkpolicy -g aksnetworkpolicy --admin
kubectl apply -f kube/namespaces.yaml
kubectl apply -f kube/

# You can curl to app2.app2.svc.cluster.local from any Pod
# You can access any Internet site from app2 namespace

# Apply network policies
kubectl apply -f networkPolicyDefaultDeny.yaml
kubectl apply -f networkPolicy.yaml

# From app1
curl app2.app2.svc.cluster.local    # Should work
curl ipconfig.io                    # Should work

# From intruder
curl app2.app2.svc.cluster.local    # Should fail

# From app2-b
curl app2.app2.svc.cluster.local    # Should work
curl ipconfig.io                    # Should fail

# From app2-c
curl app2.app2.svc.cluster.local    # Should fail


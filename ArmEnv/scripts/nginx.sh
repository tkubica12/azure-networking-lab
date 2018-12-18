#!/bin/bash
sudo apt-get update 
sudo apt-get install nginx jq -y
serverName=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/?api-version=2017-08-01" | jq -r .subscriptionId)-$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/?api-version=2017-08-01" | jq -r .resourceGroupName)
cat << EOF >> /etc/nginx/conf.d/myapp.conf
server {
  listen 8080;

  server_name $serverName.westeurope.cloudapp.azure.com;

  location / {
      proxy_pass http://10.0.32.100/;
  }
}
EOF
sudo nginx -s reload
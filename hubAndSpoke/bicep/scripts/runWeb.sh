#!/bin/bash
sudo apt update && apt install nginx -y
echo Hello from $(hostname) > /var/www/html/index.html
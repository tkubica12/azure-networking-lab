#!/bin/bash
sudo apt update && sudo apt install apache2 -y
echo "Server 1 is alive!" | sudo tee /var/www/html/index.html
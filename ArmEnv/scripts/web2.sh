#cloud-config
runcmd:
    - sudo apt update 
    - sudo apt install apache2 -y
    - echo "WEB Server 2 is alive!" | sudo tee /var/www/html/index.html
#cloud-config
runcmd:
    - curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
    - curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
    - sudo apt-get update 
    - sudo ACCEPT_EULA=Y apt-get install mssql-tools unixodbc-dev -y
    - echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /home/$(awk -F: '{ print $1}' /etc/passwd | tail -n 1)/.bashrc

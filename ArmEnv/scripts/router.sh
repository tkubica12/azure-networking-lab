#cloud-config
runcmd:
    - sudo ufw disable
    - sudo sysctl -w net.ipv4.ip_forward=1
    - echo net.ipv4.ip_forward = 1 | sudo tee /etc/sysctl.conf
    - sudo ip route add 10.0.0.0/8 via 10.0.3.1 dev eth0
    - sudo ip route change 0.0.0.0/0 via 10.0.3.65 dev eth1
    - sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
    - sudo iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    - sudo iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT
    - echo sudo ip route add 10.0.0.0/8 via 10.0.3.1 dev eth0 | sudo tee /etc/rc.local
    - echo sudo ip route change 0.0.0.0/0 via 10.0.3.65 dev eth1 | sudo tee /etc/rc.local
    - echo sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE | sudo tee /etc/rc.local
    - echo sudo iptables -A FORWARD -i eth1 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT | sudo tee /etc/rc.local
    - echo sudo iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT | sudo tee /etc/rc.local
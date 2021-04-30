cat > /etc/systemd/system/myweb.service << EOF
[Unit]
Description=MyWeb

[Service]
ExecStart=/myweb.sh

[Install]
WantedBy=multi-user.target
EOF

cat > /myweb.sh << EOF
#!/bin/bash
while true
do echo -e "HTTP/1.1 200 OK\n\n MyWEB: $(date)" | nc -l -w 1 80
done
EOF

chmod +x /myweb.sh
systemctl enable myweb
systemctl start myweb

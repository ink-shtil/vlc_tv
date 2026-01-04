sudo apt update && sudo apt upgrade -y
sudo apt install -y mpv python3 python3-pip cec-utils udisks2


sudo nano /etc/systemd/system/usb-automount.service

[Unit]
Description=USB automount
After=multi-user.target

[Service]
ExecStart=/usr/bin/udiskie --no-notify --automount
Restart=always

[Install]
WantedBy=multi-user.target


sudo systemctl daemon-reload
sudo systemctl enable usb-automount
sudo systemctl start usb-automount




blkid /dev/sda1
sudo nano /etc/fstab
UUID=XXXX-YYYY  /media/usb  exfat  defaults,nofail  0  0



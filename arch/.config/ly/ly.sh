chmod +x ~/.xinitrc

sudo pacman -S ly
sudo systemctl enable ly.service
sudo systemctl start ly.service

# config
sudo code /etc/ly/config.ini
sudo systemctl restart ly.service

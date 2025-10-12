## 1) copy vlc_tv/* to root folder
## 2) edit desktop startup config
sudo nano /etc/xdg/lxsession/LXDE-pi/autostart

#@lxpanel --profile LXDE-pi
#@pcmanfm --desktop --profile LXDE-pi
#@xscreensaver -no-splash
@/vlc_tv/start.sh
sleep 2
@/vlc_tv/switch.sh
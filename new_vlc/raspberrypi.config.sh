## 1) copy vlc_tv/* to root folder
## 2) edit desktop startup config
## sudo apt-get install netcat-traditional
## sudo apt-get install unclutter

sudo nano /etc/xdg/lxsession/rpd-x/autostart
# sudo nano /etc/xdg/lxsession/rpd-x/autostart
# @unclutter -idle 0 -root

# Improved autostart commands with log file prefixes:
# These will run your scripts at session start and log output to files prefixed with an underscore.
@/home/pda/vlc_tv/start.sh > /home/pda/vlc_tv/_start.log 2>&1 &
@bash -c 'sleep 3 && bash /home/pda/vlc_tv/switch_channel.sh current' > /home/pda/vlc_tv/_switch_channel.log 2>&1 &
@unclutter -idle 0 -root

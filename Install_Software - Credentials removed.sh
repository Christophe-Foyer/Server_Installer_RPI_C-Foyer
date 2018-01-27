#!/bin/sh

#Christophe Foyer Dec 2017
#Personal installer for server software on OSMC (DEC 2017)
#Commands sourced from:
#-https://www.htpcguides.com/install-plex-media-server-on-raspberry-pi-2/
#-https://www.htpcguides.com/install-syncthing-raspberry-pi-bittorrent-sync-alternative/
#-https://stackoverflow.com/questions/878600/how-to-create-a-cron-job-using-bash-automatically-without-the-interactive-editor
#
#Make sure you include all the included files with the installer
#Also change the settings to suit your preferences
#
#The script kinda messes up the putty terminal layout so you'll probably have to start a new seession after your run this

#General Info
HDD_loc="/media/Seagate Expansion Drive/" #"~/" is the normal install path (set this to the path you want syncthing data stored, probably a usb HDD)
user=osmc #default on raspbian is "pi", but I am using it on osmc

#Domain login info
g_usr=yourGoogleSubomainUsername #not your google account!
g_pwd=yourGoogleSubdomainPassword
g_domain="subdomain.yourdomain.com"

#Duckdns login info
duck_token="yourduckdnstoken" #you can find your token in the instalation instructions for duckdns
duck_domain="your duckdns subdomain" #.duckdns.org

if [ "$EUID" = 0 ]; then
    echo "Please do not run as root"
    exit
fi

#Let's start with permissions (not ideal way of doing this I think)
echo "Setting permissions on drive (this may take a while)"
sudo chmod 777 -R "${HDD_loc}"

#Let's start by updating things
sudo apt-get update
sudo apt-get dist-upgrade -y

# Install Plex
echo "Installing Plex"
sudo apt-get update && sudo apt-get install apt-transport-https binutils -y --force-yes
wget -O - https://dev2day.de/pms/dev2day-pms.gpg.key | sudo apt-key add -
echo "deb https://dev2day.de/pms/ jessie main" | sudo tee /etc/apt/sources.list.d/pms.list
sudo apt-get update
sudo apt-get install plexmediaserver-installer -y
sudo service plexmediaserver stop
echo "moving server data directory"
home_dir="${HDD_loc}.plexmediaserver"
mkdir "${home_dir}"
#This is dumb, keeping it (commented out) as an example though: sudo sed -i "s|PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver|PLEX_MEDIA_SERVER_HOME=\"${home_dir}\"|gi" /lib/systemd/system/plexmediaserver.service
sudo systemctl daemon-reload
sleep 5
sudo service plexmediaserver start

# Install Syncthing
echo "Installing Syncthing"
wget -O - https://syncthing.net/release-key.txt | sudo apt-key add -
echo "deb http://apt.syncthing.net/ syncthing release" | sudo tee -a /etc/apt/sources.list.d/syncthing-release.list
sudo apt-get update
sudo apt-get install syncthing -y
syncthing -home "${HDD_loc}.config/syncthing" & export last_pid=$!
echo "Waiting 30 seconds for syncthing to generate the file (may be overkill)"
sleep 30
kill -INT $last_pid
sleep 5
echo "Adding config to syncthing file"
sudo sed -i "s|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|gi" "${HDD_loc}.config/syncthing/config.xml"
options="-home \"${HDD_loc}.config/syncthing/\""
#I seem to have broken the commented out method, using cron instead (not as nice for debugging, but should get the job done)
#sudo sed -i "s|DAEMON_OPTS=\"\"|DAEMON_OPTS='${options}'|gi" syncthing.txt
#sudo sed -i "s|DAEMON_USER=pi|DAEMON_USER=${user}|gi" syncthing.txt
#sudo cp syncthing.txt /etc/init.d/syncthing
#sudo chmod +x /etc/init.d/syncthing
#sudo update-rc.d syncthing defaults
#sudo service syncthing start

#Add domain name script
sudo apt-get install dnsutils
mkdir "/home/${user}/scripts"
echo 'echo url="https://www.duckdns.org/update?domains=${duck_domain}&token=${duck_token}&ip=" | curl -k -o ~/scripts/domains.log -K -' >> domains.sh
echo 'ip="$(dig +short myip.opendns.com @resolver1.opendns.com)"' >> domains.sh
echo "curl https://${g_usr}:${g_pwd}@domains.google.com/nic/update?hostname=${g_domain}&myip=${ip}" >> domains.sh
sudo chmod 700 domains.sh

#Install crontab
echo "Installing Crontab"
sudo apt-get install cron -y
#create crontab
yes '2' | crontab -e & export last_pid=$! #selects nano, for some reason break how the terminal displays
sleep 2
kill -TSTP $last_pid
#write out current crontab
sudo crontab -l > mycron
#echo new cron into cron file
echo "0 5 * * * /sbin/shutdown -r" >> mycron #Adds reboots at 5am
echo "*/5 * * * * /home/${user}/scripts/domains.sh >/dev/null 2>&1" >> mycron #adds domain name updates
#install new cron file
sudo crontab mycron
rm mycron
#Now for non-root cron commands
crontab -l > mycron
echo "@reboot sleep 30 && /usr/bin/syncthing -home \"${HDD_loc}.config/syncthing\" &" >> mycron #for some reason doesn't work without delay
crontab mycron
rm mycron

#Echo message
echo    # move to a new line
echo "DONE"	
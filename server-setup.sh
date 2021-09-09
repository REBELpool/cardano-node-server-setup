#!/bin/bash
# This script sets up the node for use as a stake pool.

# Your home folder /home/${NODE_USER}/ & sudo username
NODE_USER="rebel" # [default: rebel]
NODE_PORT="3001" # [default: 3001]
SSH_PORT="22" # [default: 22]
SSH_PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzAonRTQrU3wupXZSgsKQTtKpkoKyL3OYbVMPKBTIpbvXYkMLdiCMdDw6x6qmoX3pWw4G2BNBEVWqpXR/zun8Z3PdSN2u83zl5FX1MV4kZmc+zW3wAgePr6tyIGdk/NFoRNnCg/keV19rvJXzqah16Qmz09vnRd5sN4bCqd8QMxoN1P5P01gOZwSBFZQDQzOQI4WchaW86CmczZKIt5/OpRKJWAlVVKibcyxcHFGO6pfeZpPXJ8Trc4TZxk31Ve9yjONjZqyrrRT01jJq4wKoEp+uk+tOZuL03kL3D8jE6bnxzojwxISSKIi0wNgASjSjLfKVPxFBLbPXEzru9KHDRSOrnlE6bfFzoIvn5ero9rzq9LlhB6vnE2vUo/Zw4ivaGcz47O8zcE9ueP2RKw8iAxGid5nwusE2G+p0A7nwLvtJiXLGqIlStG6mPkvtJamV8tmGudebaBpBO4iMnR1UXfq9reSBoczbYBVhWLSzEy+M/UGAm7CauF96R3sj8ZAg5QvxpiEbHXHfdoJEgRDjHmD6KenaETDRDXiRV4zRZQZ6J+pxA3bQmd/9vcd3iTyEVokTTMhq/ZSuvi4reMzPr1jxudkKjavMGzvfgjdZg1FBIv1dC74buVFHNk/cIAVv6tIE/Jmt6JDjLA//5atWw9qVs0c55OacPn1tcQJFB3Q==" # Your SSH Pub key for Cardano Node account

# Your static IP address
# If you have dynamic IP, please consider using Wireguard
# Tutorial: https://www.cyberciti.biz/faq/debian-10-set-up-wireguard-vpn-server/
WHITELISTED_IP="x.x.x.x" # Don't change if you want to use your current IP

#########################################
##  Do NOT modify code below this line ##
#########################################

# Run as root
if [ "$EUID" -ne 0 ]
  then echo -e "\nPlease run as 'root'\n"
  exit
fi

# Setting UTF-8 locale
locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 && update-locale LC_CTYPE=en_US.UTF-8
source ~/.bashrc
reset

# Create the ${NODE_USER} user (do not switch user)
groupadd -g 1024 ${NODE_USER}
echo -e "----------------------------------\nSet password for '${NODE_USER}' user:"
useradd -m -u 1000 -g ${NODE_USER} -s /bin/bash ${NODE_USER}
echo -e "----------------------------------"
usermod -aG sudo ${NODE_USER}
passwd ${NODE_USER}

# Install unattended-upgrades
apt update
apt -y upgrade
apt -y install unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# Install needed packages
apt -y install tmux ufw htop chrony curl jq bc wget make automake rsync htop libpam-google-authenticator prometheus-node-exporter fail2ban build-essential
apt autoremove
apt autoclean

## Chrony (use the Google Time Server)
cat <<EOF | tee /etc/chrony/chrony.conf
server time.google.com prefer iburst minpoll 1 maxpoll 1 maxsources 3
keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
logdir /var/log/chrony
log measurements statistics tracking
maxupdateskew 5.0
rtcsync
makestep 0.1 -1
leapsectz right/UTC
local stratum 10
EOF

timedatectl set-timezone UTC
systemctl stop systemd-timesyncd
systemctl disable systemd-timesyncd
systemctl restart chrony
hwclock -w

# Setup the Swap File
fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
cp /etc/fstab /etc/fstab.back
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

# Setup Secured Shared Memory
echo "tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0 0" | sudo tee -a /etc/fstab

# Setup SSH
mkdir -p ~/.ssh && echo ${SSH_PUB_KEY} >> ~/.ssh/authorized_keys
cp -r ${HOME}/.ssh /home/${NODE_USER}
chown -R ${NODE_USER}:${NODE_USER} /home/${NODE_USER}/.ssh
sed -i.bak1 "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
sed -i.bak2 "s/#PermitEmptyPasswords no/PermitEmptyPasswords no/g" /etc/ssh/sshd_config
sed -i.bak3 "s/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g" /etc/ssh/sshd_config
sed -i.bak4 "s/PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config
sed -i.bak5 "s/#Port 22/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
sed -i.bak6 "s/X11Forwarding yes/X11Forwarding no/g" /etc/ssh/sshd_config
echo "AllowUsers ${NODE_USER}" | sudo tee -a /etc/ssh/sshd_config
echo "AuthenticationMethods publickey,password publickey,keyboard-interactive" | sudo tee -a /etc/ssh/sshd_config
systemctl restart ssh

# Setting current IP to whitelisted IPs
if [ "${WHITELISTED_IP}" = "x.x.x.x" ]
    then WHITELISTED_IP="$(w -h | awk '{print $3}')"
fi

# Setup Fail2ban
cat <<EOF | tee /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
ignoreip = 127.0.0.1/8 ${WHITELISTED_IP}
EOF

# Setup the Firewall
ufw allow ${NODE_PORT}/tcp # Cardano node port (public)
ufw allow 9100/tcp # Prometheus port (public - consider move it to Wireguard)
ufw allow 12798/tcp # Prometheus port (public - consider move it to Wireguard)
ufw allow from ${WHITELISTED_IP} to any port ${SSH_PORT} # SSH port with your IP address
ufw enable

# Create user for Cardano noe
mkdir /home/${NODE_USER}/cardano-node
mkdir /home/${NODE_USER}/cardano-node/config
mkdir /home/${NODE_USER}/cardano-node/db
mkdir /home/${NODE_USER}/cardano-node/priv
mkdir /home/${NODE_USER}/cardano-node/logs
mv scripts /home/${NODE_USER}/cardano-node/scripts
touch /home/${NODE_USER}/cardano-node/db/node.socket
chown -R ${NODE_USER}:${NODE_USER} /home/${NODE_USER}/cardano-node
chmod -R 774 /home/${NODE_USER}/cardano-node
mv setup/*.sh /home/${NODE_USER}
echo "sh /home/${NODE_USER}/user-setup.sh" | tee -a /home/${NODE_USER}/.bashrc
chown -R ${NODE_USER}:${NODE_USER} /home/${NODE_USER}/*.sh && chmod +x /home/${NODE_USER}/*.sh

# Cleaning and rebooting...
rm -rf $PWD && shutdown -r 0

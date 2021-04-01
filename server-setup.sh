#!/bin/bash
# This script sets up the node for use as a stake pool.
# Developed for Debian Linux 10

# Your home folder /home/${NODE_USER}/ & sudo username
NODE_USER="rebel" # [default: rebel]

# Your static IP address
# If you have dynamic IP, please consider using Wireguard
# Tutorial: https://www.cyberciti.biz/faq/debian-10-set-up-wireguard-vpn-server/
WHITELISTED_IP="x.x.x.x" # Don't change if you want to use your current IP


#########################################
##  Do NOT modify code below this line ##
#########################################

echo "----------------------------------"
echo "This script was developed on Debian Linux 10"
echo "You are running the following version of Linux:"
. /etc/os-release && echo ${PRETTY_NAME}
echo -e "----------------------------------\n"

# Run as root
if [ "$EUID" -ne 0 ]
  then echo -e "Please run as 'root'\n"
  exit
fi

# Setting UTF-8 locale
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
cat <<EOF | tee -a ~/.bashrc 
export LC_CTYPE=en_US.UTF-8 
export LC_ALL=en_US.UTF-8
EOF
source ${HOME}/.bashrc

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
apt -y install git tmux ufw htop chrony curl rsync libpam-google-authenticator prometheus-node-exporter fail2ban
apt -y install jq bc make automake build-essential pkg-config libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev make g++ wget libncursesw5 libtool autoconf
apt autoremove
apt autoclean

# Create user for Cardano noe
mkdir /home/${NODE_USER}/cardano-node
mkdir /home/${NODE_USER}/cardano-node/config
mkdir /home/${NODE_USER}/cardano-node/db
mv scripts /home/${NODE_USER}/cardano-node/scripts
touch /home/${NODE_USER}/cardano-node/db/node.socket
chown -R ${NODE_USER}:${NODE_USER} /home/${NODE_USER}/cardano-node
chmod -R 774 /home/${NODE_USER}/cardano-node
mv cardano-setup.sh /home/${NODE_USER}
mv user-setup.sh /home/${NODE_USER}
echo "sh /home/${NODE_USER}/user-setup.sh" | tee -a /home/${NODE_USER}/.bashrc
chown -R ${NODE_USER}:${NODE_USER} /home/${NODE_USER}/*.sh && chmod +x /home/${NODE_USER}/*.sh


## Chrony (use the Google Time Server)
cat <<EOF | tee /etc/chrony/chrony.conf
server time.google.com prefer iburst minpoll 4 maxpoll 4
keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
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
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
cp /etc/fstab /etc/fstab.back
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

# Setup Secured Shared Memory
echo "tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0 0" | sudo tee -a /etc/fstab

# Setup SSH
cp -r ${HOME}/.ssh /home/${NODE_USER}
chown -R ${NODE_USER}:${NODE_USER} /home/${NODE_USER}/.ssh
sed -i.bak1 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
sed -i.bak2 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
sed -i.bak3 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
sed -i.bak4 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
echo "AllowUsers ${NODE_USER}" | sudo tee -a /etc/ssh/sshd_config
echo "AuthenticationMethods publickey,password publickey,keyboard-interactive" | sudo tee -a /etc/ssh/sshd_config
systemctl restart ssh

# Setting current IP to whitelisted IPs
if [ ${WHITELISTED_IP} = "x.x.x.x" ]
    then WHITELISTED_IP="$(echo ${SSH_CONNECTION} | awk '{print $1}')"
fi

# Setup Fail2ban
cat <<EOF | tee /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
ignoreip = 127.0.0.1/8 ${WHITELISTED_IP}
EOF

# Setup the Firewall
ufw allow 3001/tcp # Cardano node port (public)
ufw allow 9100/tcp # Prometheus port (public - consider move it to Wireguard)
ufw allow 12798/tcp # Prometheus port (public - consider move it to Wireguard)
ufw allow from ${WHITELISTED_IP} to any port 22 # SSH port with your IP address
ufw enable

# Cleaning 
rm -rf $PWD

# Reboot
shutdown -r 0
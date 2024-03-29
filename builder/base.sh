#!/bin/bash

set -ex

rm /etc/resolv.conf
echo "nameserver 1.0.0.1" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

echo "cloversim" > /etc/hostname
echo "127.0.0.1	cloversim" >> /etc/hosts

if id clover &>/dev/null; then
	echo 'clover user found, removing'
	sudo rm -rf /home/clover
	sudo deluser clover
fi

echo "=== Creating clover user"
useradd clover -s /bin/bash -m
echo "clover:clover" | chpasswd
usermod -aG sudo clover
sh -c "echo 'clover ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"


echo "=== Install base packages"
apt update
apt install -y nano \
	apt-transport-https \
	ca-certificates \
	curl \
	gnupg-agent \
	software-properties-common

echo "=== Install SSH server"
apt install openssh-server -y
systemctl enable ssh


echo "=== Fix rosout trying to allocate all memory issues"
cat << EOF > /etc/security/limits.d/30-nofilelimit.conf
#<domain>  <type>  <item>  <value>

*          soft    nofile  1024
*          hard    nofile  524288
EOF


echo "=== Install latest mesa, required for correct virgl 3d acceleration"
add-apt-repository ppa:kisak/kisak-mesa -y
apt install -y mesa-utils
echo "# Use virgl for 3d acceleration" >> /etc/environment
echo "LIBGL_ALWAYS_SOFTWARE=y" >> /etc/environment
echo "GALLIUM_DRIVER=virpipe" >> /etc/environment
echo "DISPLAY=:0" >> /etc/environment

echo "=== Install ros noetic desktop"
apt install -y curl
echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
apt update
apt install -y python3-pip python3-rosdep python3-rosinstall-generator python3-wstool build-essential ros-noetic-desktop imagemagick libjansson-dev
rosdep init

echo "=== Install butterfly terminal"
/usr/bin/python3 -m pip install butterfly[systemd]
cat > /etc/systemd/system/butterfly.service <<EOF
[Unit]
Description=Butterfly Terminal Server

[Service]
ExecStart=/usr/local/bin/butterfly.server.py --unsecure --host=0.0.0.0
User=clover
EOF
cat > /etc/systemd/system/butterfly.socket <<EOF
[Socket]
ListenStream=57575

[Install]
WantedBy=sockets.target
EOF
systemctl enable butterfly.socket

echo "=== Install ttyd terminal"
wget https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 -O /usr/bin/ttyd
chmod +x /usr/bin/ttyd
cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=Ttyd Terminal Server

[Service]
ExecStart=ttyd -p 7776 bash
User=clover
WorkingDirectory=/home/clover

[Install]
WantedBy=multi-user.target
EOF
systemctl enable ttyd.service

echo "=== Run local install script"
sudo -u clover /bin/bash /builder/local.sh

echo "=== Install additional packages dependencies"
apt install -y sshfs gvfs-fuse gvfs-backends python3-opencv byobu ipython3 byobu nmap lsof tmux vim ros-noetic-rqt-multiplot

echo "=== Cleaning up"
apt-get -y remove gdm3 gnome-shell
apt-get -y autoremove
apt-get -y autoclean
apt-get -y clean



rm -rf /builder

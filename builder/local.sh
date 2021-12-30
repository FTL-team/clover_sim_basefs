#!/bin/bash

# This script is based on https://github.com/CopterExpress/clover_vm/blob/master/scripts/install_software.sh


set -ex

echo "=== Finalize ROS setup and create Catkin workspace"

echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
source /opt/ros/noetic/setup.bash

rosdep update
mkdir -p ~/catkin_ws/src
cd ~/catkin_ws
catkin_make

echo "source ~/catkin_ws/devel/setup.bash" >> ~/.bashrc
source ~/catkin_ws/devel/setup.bash

echo "=== Get clover sources"
cd ~/catkin_ws/src
git clone --depth 1 --branch v0.22 https://github.com/CopterExpress/clover
git clone --depth 1 https://github.com/CopterExpress/ros_led
git clone --depth 1 https://github.com/ethz-asl/mav_comm

echo "=== Install dependencies with rosdep"
cd ~/catkin_ws
rosdep install --from-paths src --ignore-src -y

echo "=== Install Clover's Python dependencies"
sudo -E /usr/bin/python3 -m pip install -r ~/catkin_ws/src/clover/clover/requirements.txt

echo "=== Download PX4"
git clone --recursive --depth 1 --branch v1.12.0 https://github.com/PX4/PX4-Autopilot.git ~/PX4-Autopilot
ln -s ~/PX4-Autopilot ~/catkin_ws/src/
ln -s ~/PX4-Autopilot/Tools/sitl_gazebo ~/catkin_ws/src/
ln -s ~/PX4-Autopilot/mavlink ~/catkin_ws/src/

echo "=== Install PX4 dependencies"
~/PX4-Autopilot/Tools/setup/ubuntu.sh
pip3 install --user toml
sudo -E sh -c 'apt-get install -y ant openjdk-11-jdk' # Additional packages for jMAVSim

echo "=== Add Gazebo initialization to bashrc"
echo "source /usr/share/gazebo/setup.sh" >> ~/.bashrc

echo "=== Add Clover airframe"
ln -s ~/catkin_ws/src/clover/clover_simulation/airframes/* ~/PX4-Autopilot/ROMFS/px4fmu_common/init.d-posix/airframes/

echo "=== Install geographiclib datasets"
sudo -E sh -c '/opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh'

echo "=== Build the workspace"
cd ~/catkin_ws
catkin_make

echo "=== Expose examples"
ln -s ${HOME}/catkin_ws/src/clover/clover/examples ${HOME}/
# [[ -d ${HOME}/examples ]] # test symlink is valid

echo "=== Install npm and building documentation"
cd ${HOME}
NODE_VERSION=v10.15.0 # GitBook won't install on newer version
wget --progress=dot:giga https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-x64.tar.gz
tar -xzf node-$NODE_VERSION-linux-x64.tar.gz
sudo cp -R node-$NODE_VERSION-linux-x64/* /usr/local/
rm -rf node-$NODE_VERSION-linux-x64 node-$NODE_VERSION-linux-x64.tar.gz
echo "--- Reconfiguring npm to use local prefix"
mkdir ${HOME}/.npm-global
npm config set prefix "${HOME}/.npm-global"
export PATH=${HOME}/.npm-global/bin:$PATH
echo 'export PATH='${HOME}'/.npm-global/bin:$PATH' >> ${HOME}/.bashrc
echo "--- Installing gitbook and building docs"
cd ${HOME}/catkin_ws/src/clover
builder/assets/install_gitbook.sh
gitbook install
gitbook build
touch node_modules/CATKIN_IGNORE docs/CATKIN_IGNORE _book/CATKIN_IGNORE clover/www/CATKIN_IGNORE # ignore documentation files by catkin


echo "=== Enable roscore service"
sed -i "s/pi/${USER}/g" ${HOME}/catkin_ws/src/clover/builder/assets/roscore.service
sudo cp ${HOME}/catkin_ws/src/clover/builder/assets/roscore.service /etc/systemd/system
sudo systemctl enable roscore.service

echo "=== Install Monkey web server"
wget https://github.com/CopterExpress/clover_vm/raw/master/assets/packages/monkey_1.6.9-1_amd64.deb  -O /tmp/monkey.deb
sudo apt-get install -y /tmp/monkey.deb
sed "s/pi/${USER}/g" ${HOME}/catkin_ws/src/clover/builder/assets/monkey | sudo tee /etc/monkey/sites/default
sudo -E sh -c "sed -i 's/SymLink Off/SymLink On/' /etc/monkey/monkey.conf"
sudo cp ${HOME}/catkin_ws/src/clover/builder/assets/monkey.service /etc/systemd/system/monkey.service
sudo systemctl enable monkey




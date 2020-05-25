#!/bin/bash

## Bash script for setting up ROS Melodic (with Gazebo 9) development environment for PX4 on Ubuntu LTS (18.04). 
## It installs the common dependencies for all targets (including Qt Creator)
##
## Installs:
## - Common dependencies libraries and tools as defined in `ubuntu_sim_common_deps.sh`
## - ROS Melodic (including Gazebo9)
## - MAVROS
##
## Method:
## source ./ubuntu_sim_common_deps.sh

if [[ $(lsb_release -sc) == *"xenial"* ]]; then
  echo "OS version detected as $(lsb_release -sc) (16.04)."
  echo "ROS Melodic requires at least Ubuntu 18.04."
  echo "Exiting ...."
  return 1;
fi

echo "Downloading dependent script 'ubuntu_sim_common_deps.sh'"
# Source the ubuntu_sim_common_deps.sh script directly from github
common_deps=$(wget https://raw.githubusercontent.com/PX4/Devguide/master/build_scripts/ubuntu_sim_common_deps.sh -O -)
wget_return_code=$?
# If there was an error downloading the dependent script, we must warn the user and exit at this point.
if [[ $wget_return_code -ne 0 ]]; then echo "Error downloading 'ubuntu_sim_common_deps.sh'. Sorry but I cannot proceed further :("; exit 1; fi
# Otherwise source the downloaded script.
. <(echo "${common_deps}")

# ROS Melodic
## Gazebo simulator dependencies
sudo apt-get install protobuf-compiler libeigen3-dev libopencv-dev -y

## ROS Gazebo: http://wiki.ros.org/melodic/Installation/Ubuntu
## Setup keys
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
## For keyserver connection problems substitute hkp://pgp.mit.edu:80 or hkp://keyserver.ubuntu.com:80 above.
sudo apt-get update
## Get ROS/Gazebo
sudo apt install ros-melodic-desktop-full -y
sudo pip install -U rosinstall vcstools rospkg
sudo apt-get install python-rosdep -y
sudo apt-get install python-pip
sudo pip install -U rosdep
## Initialize rosdep
sudo rosdep init
rosdep update
## Setup environment variables
rossource="source /opt/ros/melodic/setup.bash"
if grep -Fxq "$rossource" ~/.bashrc; then echo ROS setup.bash already in .bashrc;
else echo "$rossource" >> ~/.bashrc; fi
eval $rossource

## Install rosinstall and other dependencies
sudo apt install python-rosinstall python-rosinstall-generator python-wstool build-essential -y



# MAVROS: https://dev.px4.io/en/ros/mavros_installation.html
## Install dependencies
sudo apt-get install python-catkin-tools python-rosinstall-generator -y

## Create catkin workspace
mkdir -p ~/catkin_ws/src
cd ~/catkin_ws
catkin init
wstool init src


## Install MAVLink
###we use the Kinetic reference for all ROS distros as it's not distro-specific and up to date
rosinstall_generator --rosdistro kinetic mavlink | tee /tmp/mavros.rosinstall

## Build MAVROS
### Get source (upstream - released)
rosinstall_generator --upstream mavros | tee -a /tmp/mavros.rosinstall

### Setup workspace & install deps
wstool merge -t src /tmp/mavros.rosinstall
wstool update -t src -j4
if ! rosdep install --from-paths src --ignore-src -y; then
    # (Use echo to trim leading/trailing whitespaces from the unsupported OS name
    unsupported_os=$(echo $(rosdep db 2>&1| grep Unsupported | awk -F: '{print $2}'))
    rosdep install --from-paths src --ignore-src --rosdistro melodic -y --os ubuntu:bionic
fi

if [[ ! -z $unsupported_os ]]; then
    >&2 echo -e "\033[31mYour OS ($unsupported_os) is unsupported. Assumed an Ubuntu 18.04 installation,"
    >&2 echo -e "and continued with the installation, but if things are not working as"
    >&2 echo -e "expected you have been warned."
fi

##Install geographiclib
#sudo apt install geographiclib -y
#echo "Downloading dependent script 'install_geographiclib_datasets.sh'"
## Source the install_geographiclib_datasets.sh script directly from github
#install_geo=$(wget https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh -O -)
#wget_return_code=$?
## If there was an error downloading the dependent script, we must warn the user and exit at this point.
#if [[ $wget_return_code -ne 0 ]]; then echo "Error downloading 'install_geographiclib_datasets.sh'. Sorry but I cannot proceed further :("; exit 1; fi
## Otherwise source the downloaded script.
#sudo bash -c "$install_geo"

# Alternate Install Geographiclib
sudo ./src/mavros/mavros/scripts/install_geographiclib_datasets.sh #Should work?

## Build!
catkin build
## Re-source environment to reflect new packages/build environment
catkin_ws_source="source ~/catkin_ws/devel/setup.bash"
if grep -Fxq "$catkin_ws_source" ~/.bashrc; then echo ROS catkin_ws setup.bash already in .bashrc; 
else echo "$catkin_ws_source" >> ~/.bashrc; fi
eval $catkin_ws_source

# Needed or rosrun cant find nodes from this workspace
source devel/setup.bash

# Clone PX4 Firmware and Go to the firmware directory
clone_dir=~/src
mkdir $clone_dir
cd $clone_dir
git clone https://github.com/PX4/Firmware.git
cd $clone_dir/Firmware

# Install TurboVNC and noVNC
export SOURCEFORGE="https://sourceforge.net/projects"
export TURBOVNC_VERSION="2.2.3"
export VIRTUALGL_VERSION="2.6.3"
export LIBJPEG_VERSION="2.0.4"
export NOVNC_VERSION="1.0.0"
export WEBSOCKIFY_VERSION="0.8.0"

curl -fsSL -O ${SOURCEFORGE}/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb \
        -O ${SOURCEFORGE}/libjpeg-turbo/files/${LIBJPEG_VERSION}/libjpeg-turbo-official_${LIBJPEG_VERSION}_amd64.deb \
        -O ${SOURCEFORGE}/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb
sudo dpkg -i *.deb && \
	rm -f /tmp/*.deb && \
	sudo sed -i 's/$host:/unix:/g' /opt/TurboVNC/bin/vncserver
sudo apt-get update -y
sudo apt-get install -y emacs lsof wget curl git htop less build-essential terminator make cmake net-tools lubuntu-desktop xvfb
sudo perl -pi -e 's/^lightdm:(.*)(\/bin\/false)$/lightdm:$1\/bin\/bash/' /etc/passwd

export DISPLAY=":0"
# Install display manager
sudo apt-get install lightdm -y
sudo service lightdm stop
sudo /opt/VirtualGL/bin/vglserver_config
sudo service lightdm restart

# Critical to wait a bit: you can't run xhost too fast after x starts
sleep 5
#
# This xhost command is key to getting Lubuntu working properly with nvidia-driven GPU support.
#
sudo su - lightdm -c "xhost +si:localuser:root"
sudo perl -pi -e 's/^lightdm:(.*)(\/bin\/bash)$/lightdm:$1\/bin\/false/' /etc/passwd
echo "export DISPLAY=:1" >> ~/.bashrc
echo "export PATH=:/opt/VirtualGL/bin:/opt/TurboVNC/bin:$PATH" >> ~/.bashrc

# Novnc
sudo apt -y install novnc websockify python-numpy
sudo mkdir /etc/ssl
cd /etc/ssl
sudo openssl req -x509 -nodes -newkey rsa:2048 -keyout novnc.pem -out novnc.pem -days 365 
sudo chmod 644 novnc.pem 
# /etc/ssl/novnc.pem

cd /tmp
sudo curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | sudo tar -xzf - -C /opt && \
    sudo curl -fsSL https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz | sudo tar -xzf - -C /opt && \
    sudo mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC && \
    sudo chmod -R a+w /opt/noVNC && \
    sudo mv /opt/websockify-${WEBSOCKIFY_VERSION} /opt/websockify && \
    cd /opt/websockify && sudo make && \
    cd /opt/noVNC/utils && \
    sudo ln -s /opt/websockify
sudo mv /etc/xdg/autostart/light-locker.desktop /etc/xdg/autostart/light-locker.desktop_bak
sudo mv /etc/xdg/autostart/xfce4-power-manager.desktop /etc/xdg/autostart/xfce4-power-manager.desktop_bak
sudo apt install xfce4-session xfce4-panel -y
echo "#!/bin/sh" > ~/.vnc/xstartup.turbovnc
echo "xsetroot -solid grey" >> ~/.vnc/xstartup.turbovnc
echo "/usr/bin/lxsession -s Lubuntu &" >> ~/.vnc/xstartup.turbovnc
chmod a+x ~/.vnc/xstartup.turbovnc
sudo rm -rf ~/UAV/DroneDevelopment/*.deb

sudo reboot

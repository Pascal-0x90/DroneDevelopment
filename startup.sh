#!/bin/bash -x

# Start XVnc/X/Lubuntu
sudo chmod -f 777 /tmp/.X11-unix
sudo rm -rf /tmp/.X*-lock
sudo rm -rf /tmp/.X11-unix/*
# From: https://superuser.com/questions/806637/xauth-not-creating-xauthority-file (squashes complaints about .Xauthority)
touch ~/.Xauthority
xauth generate :0 . trusted
/opt/TurboVNC/bin/vncserver -SecurityTypes None -geometry 1800x1000


# Start NoVNC. self.pem is a self-signed cert.
if [ $? -eq 0 ] ; then
	    sudo /opt/noVNC/utils/launch.sh --vnc localhost:5901 --cert /etc/ssl/novnc.pem --listen 40001;
fi
sudo websockify -D --web=/usr/share/novnc/ --cert=/etc/ssl/novnc.pem 6080 localhost:5901 


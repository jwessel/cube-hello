# This is an example of how to construct an OS container from the
# binaries in dom0 using meta-overc technology.
#
# It is assumed you have the iot-agent installed and configured to talk
# to the cloud.
# [ Skip this section if you already did this ]

smart install -y packagegroup-iot-agent
smart install -y iot-app-examples
iot-control

# It is also assumed that you have setup some kind of static mapping
# in the dom0 container and MAC address.  You can do this by logging
# into dom0 and running the following:
# [ Skip this section if you already did this ]

cat<<EOF>/var/lib/lxc/dom0/rootfs/etc/systemd/network/20-wired.network
[Match]
Name=veth*

[Network]
Address=192.168.42.3/24
Gateway=192.168.42.1
DNS=192.168.42.2
EOF

echo "lxc.network.hwaddr = `cat /sys/devices/virtual/net/veth0/address`" >> /var/lib/lxc/dom0/config

reboot

# Login to the cube-dom0 to construct your iot application container

cube-console dom0

# Get the container creation script below or
### Optionally doing it this way instead:
###   git clone https://github.com/WindRiver-OpenSourceLabs/cube-hello
###   cd cube-hello

wget https://raw.githubusercontent.com/jwessel/cube-hello/master/mk-cube-iotapp.sh


# Create the OS container as a tar.bz2 file
sh mk-cube-iotapp.sh

# Register and install the new container
cube-ctl add cube-iotapp.tar.bz2

# Setup a persistent firewall connection to the agent:
perl -p -i -e 's/^exit 0//' /var/lib/lxc/cube-iotapp/autodev
cat<<EOF>>/var/lib/lxc/cube-iotapp/autodev
ifconfig veth0 192.168.42.5 netmask 255.255.255.0 up
route add default gw 192.168.42.1
sysctl -w net.ipv4.conf.all.route_localnet=1
IP=192.168.42.3
iptables -t nat -A OUTPUT -s 127.0.0.1 -p tcp --dport 1883 -j DNAT --to-destination \$IP:1883
iptables -t nat -A POSTROUTING -s 127.0.0.1 -p tcp -j MASQUERADE

exit 0
EOF


# Start the container
cube-ctl start cube-iotapp

# Login to the cube-iotapp container
cube-console cube-iotapp
ps -ef 
tail -f app.log
# Press control-c
exit
cube-ctl del cube-iotapp

# This is an example of how to construct an OS container from the
# binaries in dom0 using meta-overc technology.

# Here instructions to run the example which you can cut and paste
# after you have logged into your target system

cube-console dom0

git clone https://github.com/WindRiver-OpenSourceLabs/cube-hello
cd cube-hello

# Create the OS container as a tar.bz2 file
sh mk-cube-hello.sh

# Register and install the new container
cube-ctl add cube-hello.tar.bz2

# At this point you will probably have to sign into the dom0 again
# because it restarts cube-cmd-server, unless you ssh'ed into dom0
cube-console dom0

# Snapshot the container so as to restore it later
/opt/overc-system-agent/overc container snapshot cube-hello dom0

# You can see the snapshot with the following
/opt/overc-system-agent/overc container list_snapshots cube-hello dom0

# Start the container
cube-ctl start cube-hello


# Login to the cube-hello container and damage it!
cube-console cube-hello
#### cube-hello login:
root
#### HelloWorld bash OS Container#
ls /
### bin  etc  lib64  opt    proc  run   sys  usr
### dev  lib  mnt    pam.d  root  sbin  tmp
### HelloWorld bash OS Container#
rm -rf /* 2> /dev/null 
### HelloWorld bash OS Container#
ls /
### -sh: ls: command not found
### HelloWorld bash OS Container#
exit

# Stop the container
cube-ctl stop cube-hello
# Roll back the container
/opt/overc-system-agent/overc container rollback cube-hello dom0
# See the snapshot is gone
/opt/overc-system-agent/overc container list_snapshots cube-hello dom0
# Create a new snapshot for a future rollback
/opt/overc-system-agent/overc container snapshot cube-hello dom0


# Start the container and see it is restored
cube-ctl start cube-hello
cube-console cube-hello
#### cube-hello login:
root
#### HelloWorld bash OS Container#
ls /
### bin  etc  lib64  opt    proc  run   sys  usr
### dev  lib  mnt    pam.d  root  sbin  tmp
### HelloWorld bash OS Container#
exit

# Now the cube-hello container can be deleted from the system

cube-ctl del cube-hello

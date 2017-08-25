#!/bin/bash
umask 22

if [ "$1" = "" ] ; then
    dest=cube-hello
else
    dest=$1
fi
mkdir $dest
cd $dest
# canonicalize path
dest=`/bin/pwd`
d=$dest

cd $d || exit 1

mkdir -p etc sbin tmp bin mnt dev/pts dev/shm proc sys usr/sbin usr/bin lib/systemd root
LONG_BITS_FLAG=`file /bin/ls.coreutils | awk '{print $3}' | awk -F"-" '{print $1}'`
if [ $LONG_BITS_FLAG -eq 64 ]; then
    mkdir -p lib64/security
else
    mkdir -p lib/security
fi

systemdbins=`ls /bin/system*|cut -c 2-`

bins="bin/cat bin/echo bin/cp bin/false bin/ln bin/ls bin/mkdir bin/more bin/mount bin/mv bin/ping bin/rm bin/sh bin/sleep bin/touch bin/true bin/umount $systemdbins lib/systemd/systemd"

# Specific file system additions for enabling of cube-console
pambins=`ls /lib*/security/*.so /lib*/libnss* |cut -c 2-`
bins="$bins bin/bash bin/login sbin/agetty usr/bin/socat $pambins"
echo root:x:0:  > etc/group
echo root:x:0:0:root:/root:/bin/sh > etc/passwd
echo root::16966:0:99999:7::: > etc/shadow
chmod 400 etc/shadow
touch etc/login.defs
mkdir etc/pam.d
cat<<EOF>etc/pam.d/login
auth    [success=1 default=ignore]      pam_unix.so nullok
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so
account [success=1 new_authtok_reqd=done default=ignore]        pam_unix.so 
account requisite                       pam_deny.so
account required                        pam_permit.so
session [default=1]                     pam_permit.so
session requisite                       pam_deny.so
session required                        pam_permit.so
session required        pam_unix.so
EOF
(
    cd /etc
    tar --xattrs --xattrs-include=security.ima -chf - pam.d | (cd $d ; tar --xattrs --xattrs-include=security.ima -xf -)
)
# end cube-console additions

ln -s /bin/systemctl sbin/halt

myldd(){
    if [ "${1%.so}" != "$1" -o "${1/.so./}" != "$1" ] ; then
	LD_TRACE_LOADED_OBJECTS=1 LD_PRELOAD=$1 /bin/echo
    else
	LD_TRACE_LOADED_OBJECTS=1 $1 |grep -v Sementation
    fi
}

for b in $bins; do 
    cp -aL /$b $b
    libs=$(myldd $b |grep "=>" |awk '{print $3}'; myldd $b |grep -v "=>" |grep -v vdso |awk '{print $1}')
    for lib in $libs; do
	lib_noabs=${lib#/}
	if [ ! -e $lib_noabs ] ; then
	    (
		cd /
		tar --xattrs --xattrs-include=security.ima -chf - $lib_noabs | (cd $d ; tar --xattrs --xattrs-include=security.ima -xf -)
	    )
	fi
    done
done

ln -s ../lib/systemd/systemd sbin/init

# Setup systemd files
mkdir -p lib/systemd/system
ln -s rescue.target lib/systemd/system/default.target
ln -s halt.target lib/systemd/system/poweroff.target

cat<<EOF>lib/systemd/system/halt.target
[Unit]
Description=Halt
Documentation=man:systemd.special(7)
DefaultDependencies=no
Requires=systemd-halt.service
After=systemd-halt.service
AllowIsolate=yes
EOF

cat<<EOF>lib/systemd/system/systemd-halt.service
[Unit]
Description=Halt
Documentation=man:systemd-halt.service(8)
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/sbin/halt -f

EOF

cat<<EOF>lib/systemd/system/rescue.service
[Unit]
Description=Shell
DefaultDependencies=no
Conflicts=shutdown.target
Before=shutdown.target

[Service]
Environment=HOME=/root
WorkingDirectory=/root
ExecStart=-/bin/sh -c "PS1='HelloWorld bash OS Container# '; export PS1; /bin/sh; /sbin/halt -f"
Type=idle
StandardInput=tty-force
StandardOutput=inherit
StandardError=inherit
KillMode=process
IgnoreSIGPIPE=no
SendSIGHUP=yes
EOF

cat<<EOF>lib/systemd/system/rescue.target
[Unit]
Description=Shell Demonstration
Documentation=man:systemd.special(7)
Requires=rescue.service
After=rescue.service
AllowIsolate=yes
EOF


# Finalize /etc/profile

cat<<EOF>etc/profile
PS1='HelloWorld bash OS Container# '
EOF

cd $dest
tar --xattrs --xattrs-include=security.ima -cjf ../cube-hello.tar.bz2 .

if [ $? = 0 ] ; then
    echo Created cube-hello.tar.bz2
fi


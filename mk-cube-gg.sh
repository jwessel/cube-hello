#!/bin/bash
umask 22

if [ "$1" = "" ] ; then
    dest=cube-gg
else
    dest=$1
fi
cubename=$dest

# Check for files which will be inserted into the image
TOP=`/bin/pwd`
CERTHASH=${CERTHASH=$(ls *-certificate.pem.crt 2>/dev/null |sed -e 's/-certificate.pem.crt//')}

GG=${GG=$TOP/$(ls greengrass-linux-x86-64-*.tar.gz 2> /dev/null)}
PRIVKEY=${PRIVKEY=$TOP/$CERTHASH-private.pem.key}
CERTKEY=${CERTKEY=$TOP/$CERTHASH-certificate.pem.crt}
CAKEY=${CAKEY=$TOP/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem}

for f in $GG $PRIVKEY $CERTKEY $CAKEY; do 
    if [ ! -e $f ] ; then
	echo "Error could not find $f"
	exit 1
    fi
done

mkdir $dest
if [ $? != 0 ] ; then
    echo "ERROR: Directory $dest already exists"
    exit 1
fi
cd $dest
# canonicalize path
dest=`/bin/pwd`
d=$dest

cd $d || exit 1

echo "-Adding in root file system binaries"
mkdir -p etc sbin tmp bin mnt dev/pts dev/shm proc sys usr/sbin usr/bin lib/systemd root
LONG_BITS_FLAG=`file /bin/ls.coreutils | awk '{print $3}' | awk -F"-" '{print $1}'`
if [ $LONG_BITS_FLAG -eq 64 ]; then
    mkdir -p lib64/security
else
    mkdir -p lib/security
fi

systemdbins=`ls /bin/system*|cut -c 2-`

bins="bin/sed usr/bin/wget bin/date bin/vi sbin/ip bin/stat usr/bin/strace sbin/ifconfig sbin/route usr/bin/find bin/chown usr/bin/which usr/bin/nohup usr/bin/sqlite3 usr/bin/id usr/bin/awk bin/grep usr/bin/dirname usr/bin/readlink bin/cat bin/echo usr/bin/env bin/cp bin/false bin/ln bin/ls bin/mkdir bin/more bin/mount bin/mv bin/ping bin/rm bin/sh bin/sleep bin/touch bin/true bin/umount $systemdbins lib/systemd/systemd bin/ps usr/bin/tail bin/kill usr/bin/stdbuf usr/bin/python2.7"

ln -s /usr/bin/python2.7 usr/bin/python

# Specific file system additions for enabling of cube-console
pambins=`ls /lib*/security/*.so /lib*/libnss* |cut -c 2-`
bins="$bins bin/bash bin/login sbin/agetty usr/bin/socat $pambins"
echo root:x:0:  > etc/group
echo nogroup:x:65534: >> etc/group
echo ggc_group:x:600: >> etc/group

echo root:x:0:0:root:/root:/bin/sh > etc/passwd
echo nobody:x:65534:65534:nobody:/nonexistent:/bin/sh >> etc/passwd
echo ggc_user:x:600:600::/home/ggc_user:/bin/sh >> etc/passwd

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
    local f
    f="$1"
    if [ "${f#/}" = "$f" ] ; then
	f="./$f"
    fi
    if [ "${f%.so}" != "$f" -o "${f/.so./}" != "$f" ] ; then
	LD_TRACE_LOADED_OBJECTS=1 LD_PRELOAD=$1 /bin/echo
    else
	LD_TRACE_LOADED_OBJECTS=1 $f |grep -v Sementation
    fi
	echo $f
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
# Fix up core-utils lib
(
cd /
tar --xattrs --xattrs-include=security.ima -chf - usr/lib64/coreutils/libstdbuf.so | (cd $d ; tar --xattrs --xattrs-include=security.ima -xf -)
)

ln -s ../lib/systemd/systemd sbin/init

# Add in specific binaries for greengrass

tar --numeric-owner -xf $GG
chown -R 600:600 greengrass

cp $PRIVKEY $CERTKEY $CAKEY greengrass/certs

[ "$ARN" = "" ] && ARN="=ARN="
[ "$CERTKEY" = "" ] && CERTKEY="=CERTKEY="
[ "$PRIVKEY" = "" ] && PRIVKEY="=PRIVKEY="
[ "$IOTHOST" = "" ] && IOTHOST="=IOTHOST="
[ "$REGION" = "" ] && REGION="=REGION="
    
cat<<EOF>greengrass/config/config.json
{
    "coreThing": {
        "caPath": "${CAKEY##*/}",
        "certPath": "${CERTKEY##*/}",
        "keyPath": "${PRIVKEY##*/}",
        "thingArn": "${ARN}",
        "iotHost": "${IOTHOST}.iot.${REGION}.amazonaws.com",
        "ggHost": "greengrass.iot.${REGION}.amazonaws.com"
    },
    "runtime": {
        "cgroup": {
            "useSystemd": "yes"
        }
    }
}
EOF
cp greengrass/config/config.json greengrass/config/config.json.orig

mkdir -p var/run var/log/journal

echo nameserver 192.168.42.1 > etc/resolv.conf

d=$PWD
(
cd /
tar --xattrs --xattrs-include=security.ima -chf - etc/ssl usr/lib*/python2* etc/terminfo | (cd $d ; tar --xattrs --xattrs-include=security.ima -xf -)
)

cp /etc/hosts etc/hosts

ln -s /greengrass/ggc/var/log root/log

cat<<EOF>root/update_config
#!/bin/bash
PRIVKEY=\$(ls /greengrass/certs/*-private.pem.key 2>/dev/null)
CERTKEY=\$(ls /greengrass/certs/*-certificate.pem.crt 2>/dev/null)
if [ "\$PRIVKEY" = "" ] ; then
    echo "ERROR: No private key found please set PRIVKEY"
    exit 1
fi
if [ "\$CERTKEY" = "" ] ; then
    echo "ERROR: No private key found please set CERTKEY"
    exit 1
fi

if [ "\$ARN" = "" ] ; then
    echo -n "Enter ARN: "
    read ARN
fi
if [ "\$IOTHOST" = "" ] ; then
    echo -n "Enter IOTHOST: "
    read IOTHOST
fi
if [ "\$REGION" = "" ] ; then
    echo -n "Enter REGION: "
    read REGION
fi
cp /greengrass/config/config.json.orig /greengrass/config/config.json
sed -i -e "s#=CERTKEY=#\${CERTKEY##*/}#; s#=PRIVKEY=#\${PRIVKEY##*/}#; s#=ARN=#\$ARN#; s#=IOTHOST=#\$IOTHOST#; s#=REGION=#\$REGION#" /greengrass/config/config.json

echo Restarting application service
systemctl restart app

EOF

chmod 755 root/update_config

if [ -e $TOP/ima_privkey.pem ] ; then
    echo "-Signing binaries"
    evmctl ima_sign --rsa --hashalgo sha256 --key $TOP/ima_privkey.pem greengrass/ggc/core/greengrassd
    evmctl ima_sign --rsa --hashalgo sha256 --key $TOP/ima_privkey.pem greengrass/ggc/core/bin/daemon
    evmctl ima_sign --rsa --hashalgo sha256 --key $TOP/ima_privkey.pem root/update_config
fi

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

cat<<EOF>lib/systemd/system/app.service
[Unit]
Description=Iot App
DefaultDependencies=no

[Service]
Environment=HOME=/root
WorkingDirectory=/root
# Note that if the ls for the *.key fails the nothing continues further
ExecStartPre=/bin/sh -c "ifconfig veth0 192.168.42.88 netmask 255.255.255.0 up; route add default gw 192.168.42.1; ls /greengrass/certs/*.key 2>/dev/null"
ExecStart=/bin/bash /greengrass/ggc/core/greengrassd start
Type=forking
PIDFile=/var/run/greengrassd.pid
Restart=always
RestartSec=2
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
ExecStart=-/bin/sh -c "PS1='$cubename# '; export PS1; /bin/sh; /sbin/halt -f"
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
Requires=app.service
After=rescue.service
AllowIsolate=yes
EOF


# Finalize /etc/profile

cat<<EOF>etc/profile
PS1='$cubename# '
EOF

echo "-Compressing and creating: $cubename.tar.bz2"
cd $dest
tar --xattrs --xattrs-include=security.ima -cjf ../$cubename.tar.bz2 .

if [ $? = 0 ] ; then
    echo "-Created $cubename.tar.bz2"
fi

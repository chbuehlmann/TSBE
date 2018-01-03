#!/bin/sh
# Script to install a PXE-Server (including DHCP and TFTPD). Please enshure a static IP like 
# The Management-Network
# auto ens19
# iface ens19 inet static
# address 192.168.1.10
# netmask 255.255.255.0
# in /etc/network/interfaces
# You should be root! (not sudo)
rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"  # Modified as suggested below.
        exit $?
    fi
}
# install all Stuff
apt-get update -y
apt-get upgrade -y
apt-get install isc-dhcp-server tftpd-hpa nfs-kernel-server syslinux pxelinux nginx -y
# configure nginx (Git-Checkout because working woth only a Proxy is behind the EDU-Intrusion Detection of GIBB not this easy)
sed -i 's$location / {$location /repo {\n\t\tproxy_pass https://raw.githubusercontent.com/chbuehlmann/TSBE/master;\n\t}\n\n\tlocation / {$' /etc/nginx/sites-enabled/default
cd /var/www/html/
git clone https://github.com/chbuehlmann/TSBE.git
git checkout develop
# configure ISC DHCP
echo "authoritative;
allow booting;
allow bootp;

next-server 192.168.1.10;
filename \"/pxelinux.0\";

subnet 192.168.1.0 netmask 255.255.255.0 {
    range 192.168.1.50 192.168.1.254;
    option broadcast-address 192.168.1.255;
    option routers 192.168.1.2;
    option domain-name-servers 192.168.1.2;
}
" >> /etc/dhcp/dhcpd.conf
# configure TFTP
echo "TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/var/lib/tftpboot"
TFTP_ADDRESS="192.168.1.50:69"
TFTP_OPTIONS="-l --secure"" >> /etc/default/tftp-hpa

echo "/var/lib/tftpboot 192.168.1.0/255.255.255.0(rw,no_root_squash,no_subtree_check,async)"

exportfs -ra

# add PXE-Files
mkdir -p /var/lib/tftpboot/pxelinux.cfg 

cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot
cp /usr/lib/syslinux/modules/bios/menu.c32 /var/lib/tftpboot
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /var/lib/tftpboot
cp /usr/lib/syslinux/modules/bios/libcom32.c32 /var/lib/tftpboot
cp /usr/lib/syslinux/modules/bios/libutil.c32 /var/lib/tftpboot
cp /usr/lib/syslinux/modules/bios/chain.c32 /var/lib/tftpboot

mkdir -p /var/lib/tftpboot/memtest 
cd /var/lib/tftpboot/memtest
wget http://www.memtest.org/download/5.01/memtest86+-5.01.bin.gz
gunzip memtest86+-5.01.bin.gz
mv memtest86+-5.01.bin memtest86

echo "DEFAULT menu.c32
ALLOWOPTIONS 0
PROMPT 0
TIMEOUT 0

MENU TITLE TSBE VIRT PXE Boot Server

MENU AUTOBOOT Starting Ubuntu Xenial 64-Bit in # seconds
timeout 300

label memtest
        menu label ^Memtest86+
        kernel memtest/memtest86

label cli
        menu label ^Ubuntu Xenial 64-Bit install
        menu default
        kernel ubuntu-installer/amd64/linux
        append ramdisk_size=14984 locale=de_CH console-setup/layoutcode=ch url=http://192.168.1.10/TSBE/ubuntu-installation/preseed.cfg netcfg/get_hostname=ubuntu priority=critical vga=normal initrd=ubuntu-installer/amd64/initrd.gz  

label proxmox-install
        menu label ^Proxmox Install
        linux proxmox/pxeboot/linux26
        append vga=791 video=vesafb:ywrap,mtrr ramdisk_size=4000000 rw quiet splash=silent
        initrd proxmox/pxeboot/initrd.iso.img splash=verbose

label proxmox-debug-install
        menu label Proxmox Install (^Debug Mode)
        linux proxmox/pxeboot/linux26
        append vga=791 video=vesafb:ywrap,mtrr ramdisk_size=4000000 rw quiet splash=verbose proxdebug
        initrd proxmox/pxeboot/initrd.iso.img splash=verbose

" >> /var/lib/tftpboot/pxelinux.cfg/default

mkdir -p /var/lib/tftpboot/proxmox 
cd /var/lib/tftpboot/proxmox
git clone https://github.com/morph027/pve-iso-2-pxe.git
wget -O proxmox.iso http://download.proxmox.com/iso/proxmox-ve_5.1-3.iso
/bin/bash /var/lib/tftpboot/proxmox/pve-iso-2-pxe/pve-iso-2-pxe.sh /var/lib/tftpboot/proxmox/proxmox.iso

mkdir -p /var/lib/tftpboot/ubuntu-installer 
cd /var/lib/tftpboot/ubuntu-installer 
wget -r -np -R "index.html*" -nH --cut-dirs=9 http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/

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
rootcheck
apt-get update -y
apt-get upgrade -y
apt-get install dnsmasq tftpd-hpa nfs-kernel-server syslinux pxelinux nginx -y
# configure static IP 
sed -i 's$iface ens19 inet dhcp$iface ens19 inet static\naddress 192.168.1.10\nnetmask 255.255.255.0\ndns-nameservers 192.168.1.2$' /etc/network/interfaces
# configure nginx (Git-Checkout because working woth only a Proxy is behind the EDU-Intrusion Detection of GIBB not this easy)
sed -i '/^#/! s$location / {$location /repo {\n\t\tproxy_pass https://raw.githubusercontent.com/chbuehlmann/TSBE/master;\n\t}\n\n\tlocation / {$' /etc/nginx/sites-enabled/default
cd /var/www/html/
git clone -b develop https://github.com/chbuehlmann/TSBE.git
# configure DNSMASQ
echo "
domain-needed
bogus-priv

resolv-file=/etc/ppp/resolv.conf

expand-hosts

domain=tsbe.local
dhcp-option=option:router,192.168.1.2
dhcp-leasefile=/var/lib/misc/dnsmasq.leases
dhcp-authoritative
dhcp-range=192.168.1.50,192.168.1.254,255.255.255.0,15m

dhcp-host=D4:85:64:58:36:10,blade1
dhcp-host=00:25:B3:A4:24:A8,blade2

# Enable dnsmasq's built-in TFTP server
enable-tftp
tftp-root=/var/lib/tftpboot
dhcp-boot=pxelinux.0
" >> /etc/dnsmasq.conf

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
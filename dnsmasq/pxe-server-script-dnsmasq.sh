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
apt-get install ntp nfs-kernel-server syslinux pxelinux nginx -y

# configure nginx (Git-Checkout because working woth only a Proxy is behind the EDU-Intrusion Detection of GIBB not this easy)
sed -i '/^#/! s$location / {$location /repo {\n\t\tproxy_pass https://raw.githubusercontent.com/chbuehlmann/TSBE/master;\n\t}\n\n\tlocation / {$' /etc/nginx/sites-enabled/default
cd /var/www/html/
git clone -b develop https://github.com/chbuehlmann/TSBE.git

echo "*/1 * * * * root cd /var/www/html/TSBE && /usr/bin/git pull -q origin develop
" >> /etc/crontab

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

MENU AUTOBOOT Debian Stretch 64-Bit in # seconds
timeout 300

label memtest
        menu label ^Memtest86+
        kernel memtest/memtest86

label ubuntu-no-preseed
        menu label Ubuntu Xenial 64-Bit install (no preseed)
        kernel ubuntu-installer/amd64/linux
        append ramdisk_size=14984 locale=de_CH console-setup/layoutcode=ch netcfg/get_hostname=ubuntu priority=critical vga=normal
        initrd ubuntu-installer/amd64/initrd.gz    

label ubuntu-preseed
        menu label Ubuntu Xenial 64-Bit install (no ETH-intf preselected)
        kernel ubuntu-installer/amd64/linux
        append ramdisk_size=14984 locale=de_CH console-setup/layoutcode=ch url=http://192.168.1.10/TSBE/ubuntu-installation/preseed.cfg netcfg/get_hostname=ubuntu priority=critical vga=normal initrd ubuntu-installer/amd64/initrd.gz  

label ubuntu-preseed-preselected-ethernet
        menu label ^Ubuntu Xenial 64-Bit install
        kernel ubuntu-installer/amd64/linux
        append ramdisk_size=14984 locale=de_CH console-setup/layoutcode=ch netcfg/choose_interface=enp2s0f0 url=http://192.168.1.10/TSBE/ubuntu-installation/preseed.cfg netcfg/get_hostname=ubuntu priority=critical vga=normal initrd ubuntu-installer/amd64/initrd.gz  
		
label debian-preseed-preselected-ethernet
        menu label ^Debian Stretch 64-Bit install
        menu default
        kernel debian-installer/amd64/linux
        append ramdisk_size=14984  locale=de_CH console-setup/layoutcode=ch keymap=ch netcfg/choose_interface=enp2s0f0 url=http://192.168.1.10/TSBE/debian-installation/preseed.cfg netcfg/get_hostname=debian priority=critical vga=normal initrd debian-installer/amd64/initrd.gz  	
		
label debian-no-preseed
        menu label Debian Stretch 64-Bit install (no preseed)
        kernel debian-installer/amd64/linux
        append ramdisk_size=14984 locale=de_CH console-setup/layoutcode=ch keymap=ch priority=critical vga=normal
		initrd debian-installer/amd64/initrd.gz  

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

# ubuntu Netinstall
mkdir -p /var/lib/tftpboot/ubuntu-installer 
cd /var/lib/tftpboot/ubuntu-installer 
wget -r -np -R "index.html*" -nH --cut-dirs=9 http://archive.ubuntu.com/ubuntu/dists/xenial-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/

# debian Netinstall (mit Non-Free Drivers nach https://cptyesterday.wordpress.com/2012/06/11/adding-non-free-drivers-to-a-debian-netboot-initrd/)
mkdir -p /var/lib/tftpboot/debian-installer/tmp
cd /var/lib/tftpboot/debian-installer 
wget -e robots=off -r -np -R "index.html*" -nH --cut-dirs=9 http://debian.ethz.ch/debian/dists/stretch/main/installer-amd64/current/images/netboot/debian-installer/amd64/

cp /var/lib/tftpboot/debian-installer/amd64/initrd.gz /var/lib/tftpboot/debian-installer/tmp
cd /var/lib/tftpboot/debian-installer/tmp 
gunzip <initrd.gz | cpio --extract --preserve --verbose
rm /var/lib/tftpboot/debian-installer/tmp/initrd.gz
mkdir -p /var/lib/tftpboot/debian-installer/tmp/lib/firmware

wget http://debian.ethz.ch/debian/pool/non-free/f/firmware-nonfree/firmware-bnx2_20161130-3_all.deb
wget http://debian.ethz.ch/debian/pool/non-free/f/firmware-nonfree/firmware-bnx2x_20161130-3_all.deb

dpkg -x firmware-bnx2_20161130-3_all.deb ./
dpkg -x firmware-bnx2x_20161130-3_all.deb ./

find . | cpio --create --format='newc' | gzip >../amd64/initrd.gz

# install and configure DNSMASQ
apt-get install dnsmasq -y
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
dhcp-host=00:25:B3:A6:91:10,blade3
dhcp-host=00:25:B3:A5:BC:A0,blade4
dhcp-host=D4:85:64:58:A4:40,blade5
dhcp-host=00:25:B3:A4:04:30,blade6
dhcp-host=00:25:B3:A4:E1:A8,blade7
dhcp-host=00:25:B3:A3:0F:40,blade8
dhcp-host=D4:85:64:58:07:B8,blade9
dhcp-host=00:25:B3:A4:14:88,blade10
dhcp-host=D4:85:64:58:94:80,blade11
dhcp-host=D4:85:64:58:17:50,blade12
dhcp-host=D4:85:64:58:F6:30,blade13
dhcp-host=D4:85:64:58:94:98,blade14
dhcp-host=D4:85:64:58:E6:F8,blade15
dhcp-host=D4:85:64:58:B6:30,blade16

# Enable dnsmasq's built-in TFTP server
enable-tftp
tftp-root=/var/lib/tftpboot
dhcp-boot=pxelinux.0

conf-file/var/www/html/TSBE/dnsmasq/staticdhcp.conf
" >> /etc/dnsmasq.conf
echo "nameserver 8.8.8.8
nameserver 8.8.4.4
" >> /etc/ppp/resolv.conf

# configure static IP 
sed -i 's$iface ens18 inet dhcp$iface ens18 inet static\naddress 192.168.1.10\nnetmask 255.255.255.0\ngateway 192.168.1.2\ndns-nameservers 192.168.1.2\ndns-search tsbe.local$' /etc/network/interfaces
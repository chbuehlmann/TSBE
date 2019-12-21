#!/bin/sh

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
apt-get install ntp nfs-kernel-server -y

mkdir -p /mnt/sharedfolder
echo "/mnt/sharedfolder 192.168.1.0/24(rw,sync,no_subtree_check)
" > /etc/exports

exportfs -ra
service nfs-kernel-server restart

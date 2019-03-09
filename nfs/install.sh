apt-get install nfs-kernel-server
mkdir -p /mnt/sharedfolder
chown nobody:nogroup /mnt/sharedfolder
chmod 777 /mnt/sharedfolder

echo "
/mnt/sharedfolder 192.168.1.0/24(rw,sync,no_subtree_check)
" >> /etc/exports

exportfs -a
systemctl restart nfs-kernel-server
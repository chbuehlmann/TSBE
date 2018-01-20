# You should be root! (not sudo)
sed -i '/puppet.tsbe.local/d' /etc/hosts
apt-get -y install ca-certificates

wget https://apt.puppetlabs.com/puppet5-release-xenial.deb
dpkg -i puppet5-release-xenial.deb
apt-get update
apt-get install -y puppetserver nano
sed -i 's$-Xms2g -Xmx2g$-Xms512m -Xmx512m$' /etc/default/puppetserver
sed -i 's$secure_path="$secure_path="/opt/puppetlabs/bin/:$' /etc/sudoers

# As each Puppet agent runs for the first time, it submits a certificate signing request (CSR) to the certificate authority (CA) Puppet master.
# You must log into that server to check for and sign certificates. On the Puppet master:
#  sudo /opt/puppetlabs/bin/puppet cert list to see any outstanding requests.
#  sudo /opt/puppetlabs/bin/puppet cert sign <NAME> to sign a request.
# After an agent’s certificate is signed, it regularly fetches and applies configuration catalogs from the Puppet master.
# for the automated Config see https://serverfault.com/questions/846657/puppet-assign-nodes-to-environments-from-master
# and https://puppet.com/blog/git-workflows-puppet-and-r10k
cd /etc/puppetlabs
git clone -b develop https://github.com/chbuehlmann/TSBE.git

chmod +x /etc/puppetlabs/TSBE/puppet/node.sh

echo "
node_terminus = exec
external_nodes = /etc/puppetlabs/TSBE/puppet/node.sh
" >> /etc/puppetlabs/puppet/puppet.conf

gem install r10k
mkdir -p /etc/puppetlabs/r10k
echo "sources:
  puppet:
    remote: 'git://github.com/chbuehlmann/tsbe-environments'
    basedir: '/etc/puppetlabs/code/environments'
" >> /etc/puppetlabs/r10k/r10k.yaml

systemctl start puppetserver

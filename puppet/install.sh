# You should be root! (not sudo)
sed -i '/puppet.tsbe.local/d' /etc/hosts
apt-get -y install ca-certificates

wget https://apt.puppetlabs.com/puppet5-release-xenial.deb
dpkg -i puppet5-release-xenial.deb
apt-get update
apt-get install -y puppetserver nano
sed -i 's$-Xms2g -Xmx2g$-Xms512m -Xmx512m$' /etc/default/puppetserver
sed -i 's$secure_path="$secure_path="/opt/puppetlabs/bin/:$' /etc/sudoers

add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y postgresql-9.6

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
storeconfigs = true
storeconfigs_backend = puppetdb
node_terminus = exec
external_nodes = /etc/puppetlabs/TSBE/puppet/node.sh
reports = store,puppetdb
" >> /etc/puppetlabs/puppet/puppet.conf

echo "
[main]
server_urls = https://puppet:8081
" >> /etc/puppetlabs/puppet/puppetdb.conf

echo "
master:
  facts:
    terminus: puppetdb
    cache: yaml
" >> /etc/puppetlabs/puppet/routes.yaml

gem install r10k
mkdir -p /etc/puppetlabs/r10k
echo "sources:
  puppet:
    remote: 'git://github.com/chbuehlmann/tsbe-environments'
    basedir: '/etc/puppetlabs/code/environments'
" >> /etc/puppetlabs/r10k/r10k.yaml

echo "*/1 * * * * root cd /etc/puppetlabs/TSBE && /usr/bin/git pull -q origin develop
*/1 * * * * root /usr/local/bin/r10k deploy environment -pv
" >> /etc/crontab

chown -R puppet:puppet `/opt/puppetlabs/bin/puppet config print confdir`

su - postgres
 createdb -O puppetdb puppetdb
 psql -c "CREATE USER puppetdb WITH PASSWORD 'puppetdb';"
exit

echo "
[database]
classname = org.postgresql.Driver
subprotocol = postgresql
subname = //localhost:5432/puppetdb
username = puppetdb
password = puppetdb
" >> /etc/puppetlabs/puppetdb/conf.d/database.ini

systemctl start puppetserver

/opt/puppetlabs/bin/puppet resource package puppetdb ensure=latest
/opt/puppetlabs/bin/puppet resource service puppetdb ensure=running enable=true
/opt/puppetlabs/bin/puppet resource package puppetdb-termini ensure=latest
#!/bin/bash

# 

# Installing Nagios on Oracle Linux 8.8
# https://support.nagios.com/kb/article/nagios-core-installing-nagios-core-from-source-96.html#Oracle_Linux
# 
dnf install -y gcc glibc glibc-common perl httpd php wget gd gd-devel
dnf install openssl-devel
dnf update -y
yum install rrdtool perl-Time-HiRes rrdtool-perl php-gd -y
yum install -y yum-utils
yum-config-manager --enable ol8_optional_latest
cd ~/tmp
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
rpm -ihv epel-release-latest-8.noarch.rpm
yum install -y gcc glibc glibc-common make gettext automake autoconf wget openssl-devel net-snmp net-snmp-utils
yum --enablerepo=powertools,epel install perl-Net-SNMP
yum install -y perl-Net-SNMP

cd ~/tmp
wget -nc https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.14.tar.gz
wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.4.6.tar.gz
wget -nc https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-4.0.2/nrpe-4.0.2.tar.gz
wget https://downloads.sourceforge.net/project/pnp4nagios/PNP-0.6/pnp4nagios-0.6.26.tar.gz
wget wget https://dl.grafana.com/oss/release/grafana-5.4.2-1.x86_64.rpm
sudo yum localinstall grafana-5.4.2-1.x86_64.rpm -y


tar xzf nagios-4.4.14.tar.gz
tar xzf nagios-plugins-release-2.4.6.tar.gz
tar xzf nrpe-4.0.2.tar.gz
tar xzf pnp4nagios-0.6.26.tar.gz

sudo useradd -m -s /bin/bash nagios
echo 'Enter the password for the new user nagios'
sudo passwd nagios
sudo groupadd apache
sudo usermod -a -G nagios apache

cd ~/tmp/nagios-4.4.14
./configure 
make all
make install-groups-users
usermod -a -G nagios apache
sudo make install
sudo make install-daemoninit
sudo make install-commandmode
make install-config
sudo make install-webconf
echo 'Enter the password for the user nagiosadmin'
sudo htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
systemctl restart httpd

cd ~/tmp/nagios-plugins-release-2.4.6/
./tools/setup
./configure
make
make install

 cd ~/tmp/nrpe-4.0.2
./configure --enable-command-args --with-nrpe-user=nagios --with-nrpe-group=nagios
make check nrpe
make check_nrpe
make install plugin
make install-plugin

cd ~/tmp/pnp4nagios-0.6.26
./configure
make all
make full install
make fullinstall
 cp contrib/ssi/status-header.ssi /usr/local/nagios/share/ssi
chkconfig --add npcd && chkconfig --level 35 npcd on

cd /usr/local/pnp4nagios/share/application/controllers/
wget -O api.php "https://github.com/lingej/pnp-metrics-api/raw/master/application/controller/api.php"


# configuring status-json
cd ~/tmp/nagios/cgi
# http://exchange.nagios.org/directory/Addons/APIs/JSON/status-2Djson/details
wget -O status-json.c "http://exchange.nagios.org/components/com_mtree/attachment.php?link_id=2498&cf_id=24"
cp status-json.c status-json.c.original
cp Makefile Makefile.original
patch -R Makefile < ~/tools/installation-scripts/nagios/Makefile.patch
patch -R status-json.c < ~/tools/installation-scripts/nagios/status-json.c.patch
make all
sudo make install
firewall-cmd --zone=public --add-port=80/tcp
firewall-cmd --zone=public --add-port=80/tcp --permanent

sudo sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

sudo mkdir -p /usr/local/nagios/var/archives
sudo chown -R nagios:nagios /usr/local/nagios
systemctl restart httpd
systemctl restart nagios.service


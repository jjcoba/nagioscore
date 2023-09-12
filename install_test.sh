#!/bin/bash

#

nagioscore_version="4.4.14"
pnp4nagios_version="0.6.26"
nrpe_version="4.0.2"
nagiosplugins_version="2.4.6"

temp_path="/tmp/nagios_`date +%Y%m%d%H%M%S`"
user_nagios="nagios"
hostname="nagioscore"
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

user_exist() {
  if id "$1" >/dev/null 2>&1; then
    echo "user $1 exists"
  else
    groupadd $1 && useradd -m -d $2 -g $1 -s /bin/bash $1 &&
    su - $1 -c "ssh-keygen -f $2/.ssh/id_rsa -t rsa -N ''"
  fi
}

  apt-get -y update && apt-get -y upgrade &&
  apt-get install -y make wget gcc g++ libssl-dev libkrb5-dev &&
  apt-get install -y ntp curl fping nmap vim graphviz tcpdump iptraf sudo rsync gawk whois dnsutils exim4 dos2unix sysstat &&
  apt-get install -y apache2 ssl-cert libapache2-mod-auth-ntlm-winbind libfontconfig-dev vim-gtk libgd2-xpm-dev libltdl-dev libssl-dev libclass-csv-perl &&
  apt-get install -y php-pear libapache2-mod-php php-snmp php-gd php-mysql php-ldap *libmysqlclient-dev
  apt-get install -y rrdtool librrds-perl libmcrypt-dev unzip &&
  apt-get install -y snmpd snmp libnet-snmp-perl &&
  return 0


install_nagioscore() {
  user_exist ${user_nagios} ${install_path} &&
  mkdir -p ${temp_path} && cd ${temp_path} &&
  wget https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${nagioscore_version}.tar.gz &&
  tar -zxf nagios-${nagioscore_version}.tar.gz &&
  cd nagios-${nagioscore_version} &&
  ./configure --prefix=${install_path} --with-nagios-user=${user_nagios} --with-nagios-group=${user_nagios} --enable-event-broker --with-htmurl=/nagios --with-init-type=${INIT_TYPE} && make all && make install && make install-daemoninit && make install-commandmode && make install-config &&
  sed -i "s/#  SSLRequireSSL/   SSLRequireSSL/g" ${temp_path}/nagios-${nagioscore_version}/sample-config/httpd.conf &&
  make install-webconf && make install-exfoliation &&
  return 0
}

configure_nagioscore() {
  /usr/bin/htpasswd -bc ${install_path}/etc/htpasswd.users nagiosadmin ${nagiosadmin_passwd} &&
  echo ${hostname} > /etc/hostname &&
  echo rocommunity nagios 127.0.0.1 >> /etc/snmp/snmpd.conf &&
  ln -sf /usr/bin/mail /bin/mail &&
  /usr/sbin/usermod -G ${user_nagios} ${user_apache} &&
  systemctl restart httpd &&
  service nagios start &&
  return 0
}

install_nagiosplugins() {  
  wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-${nagiosplugins_version}.tar.gz &&
  tar -zxf nagios-${nagiosplugins_version}.tar.gz &&
  cd nagios-${nagiosplugins_version} &&
  ./tools/setup &&
  ./configure && make && make install &&
  return 0


install_nrpe() {
  wget -P https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-${nrpe_version}.tar.gz &&
  tar -zxf nrpe-${nrpe_version}.tar.gz &&
  cd nrpe-${nrpe_version} && 
./configure && make all && make install && make install-config && make install-init &&
service nrpe start &&
  return 0
}

install_pnp4nagios() {
  mkdir -p ${temp_path} && cd ${temp_path} &&
  wget http://downloads.sourceforge.net/project/pnp4nagios/PNP-0.6/pnp4nagios-${pnp4nagios_version}.tar.gz &&
  tar -zxf pnp4nagios-${pnp4nagios_version}.tar.gz && cd pnp4nagios-${pnp4nagios_version} &&
  ./configure --with-nagios-user=${user_nagios} --with-nagios-group=${user_nagios} --prefix=${install_pnp4nagios} && make all && make fullinstall && make install-config && make install-init &&
  return 0
}

install_grafana() {
  apt-get install -y apt-transport-https
  apt-get install -y software-properties-common wget
  wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
  add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
  apt-get update
  apt-get install grafana
  systemctl enable grafana-server
  systemctl start grafana-server
  /usr/sbin/grafana-cli plugins install sni-pnp-datasource
  systemctl restart grafana-server.service
  wget -O /opt/pnp4nagios/share/application/controllers/api.php "https://github.com/lingej/pnp-metrics-api/raw/master/application/controller/api.php"
  sed -i '/Require valid-user/a\        Require ip 127.0.0.1 ::1' /etc/apache2/sites-enabled/pnp4nagios.conf
  systemctl restart httpd &&
}

configure_pnp4nagios() {
  mkdir -p ${temp_path} && cd ${temp_path} &&
  cat <<'EOF' >> host_perfdata_file.txt
#
host_perfdata_command=process-host-perfdata
service_perfdata_command=process-service-perfdata
#
service_perfdata_file=/opt/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\tTIMET::$TIMET$\tHOSTNAME::$HOSTNAME$\tSERVICEDESC::$SERVICEDESC$\tSERVICEPERFDATA::$SERVICEPERFDATA$\tSERVICECHECKCOMMAND::$SERVICECHECKCOMMAND$\tHOSTSTATE::$HOSTSTATE$\tHOSTSTATETYPE::$HOSTSTATETYPE$\tSERVICESTATE::$SERVICESTATE$\tSERVICESTATETYPE::$SERVICESTATETYPE$

service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-service-perfdata-file
#
host_perfdata_file=/opt/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\tTIMET::$TIMET$\tHOSTNAME::$HOSTNAME$\tHOSTPERFDATA::$HOSTPERFDATA$\tHOSTCHECKCOMMAND::$HOSTCHECKCOMMAND$\tHOSTSTATE::$HOSTSTATE$\tHOSTSTATETYPE::$HOSTSTATETYPE$

host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-host-perfdata-file
EOF

mkdir -p ${temp_path} && cd ${temp_path} &&
cat <<'EOF' >> command_perfdata_file.txt
#
define command {
 command_name process-service-perfdata-file
 command_line /bin/mv /opt/pnp4nagios/var/service-perfdata /opt/pnp4nagios/var/spool/service-perfdata.$TIMET$
}

define command {
 command_name process-host-perfdata-file
 command_line /bin/mv /opt/pnp4nagios/var/host-perfdata /opt/pnp4nagios/var/spool/host-perfdata.$TIMET$
}
EOF
  cat command_perfdata_file.txt >> $install_path/etc/objects/commands.cfg &&
  cp /etc/httpd/conf.d/pnp4nagios.conf /etc/apache2/sites-enabled/pnp4nagios.conf &&
  sed -i "s/AuthUserFile \/usr\/local\/nagios/AuthUserFile \/opt\/nagios/g" /etc/apache2/sites-enabled/pnp4nagios.conf &&
  mv ${install_pnp4nagios}/share/install.php ${install_pnp4nagios}/share/install.old &&
  sed -i "s/process_performance_data=0/process_performance_data=1/g" ${install_path}/etc/nagios.cfg &&
  file_exist ${install_path}/etc/nagios.cfg &&
  sed -i "/process_performance_data=1/r host_perfdata_file.txt" ${install_path}/etc/nagios.cfg &&
  update-rc.d npcd defaults &&
  service npcd start &&
  service npcd status &&
  return 0
}

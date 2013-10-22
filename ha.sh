#!/bin/bash

# For this script to run correctly you must install Elastix using the Advanced settings and set your
# partitions like this:
# /dev/sda1 /boot
# /dev/sda2 /
# /dev/sda3 /share
# /dev/sda4 swap
#
# The partition /dev/sda3 must be identical in size on both server or they will never synchronize over
# DRBD.

# Your servers should also be set up as described below:
# The server has two network interfaces
# - eth1 is used to communication to the LAN
# - eth0 is used for Heartbeat and is connected via a crossover cable to the another server eth0

# Elastix PBX Cluster Configuration Script for version 1.6
# Original Taken from http://www.voip-info.org/wiki/index.php?page_id=5165 (Royce) for Trixbox 2.6
# Updated Bradley D. Jensen <bjensen@onenetwork.com> (20090824) for Trixbox 2.8.
# Modified by Guillermo Salas M <gsalas@mantareys.com> to make it work on a Elastix 1.6 install (20100201)

# Make sure you edit this section to your requirements! Start 
cluster_ip='207.47.73.220'
cluster_broadcast='207.255.255.255'
domain_name="elx.cfbtel.com"
gateway='207.47.73.193'
primary_dns='8.8.8.8'
secondary_dns='4.2.2.2'
master_hostname='elx1.cfbtel.com'
master_ip_address_eth1='192.168.10.30'
master_ip_address_eth0='207.47.73.222'
slave_hostname='elx2.cfbtel.com'
slave_ip_address_eth1='192.168.10.31'
slave_ip_address_eth0='207.47.73.217'
subnet_mask_eth1='255.255.255.0'
subnet_mask_eth0='255.255.255.224'
drbd_disk='/dev/sda3'
drbd_device='/dev/drbd0'
# Make sure you edit this section to your requirements! End 

clear
echo "Elastix High Availability Cluster Installation Script"
echo
echo "1. Master node"
echo "2. Master node (pause after each section)"
echo "3. Slave node"
echo "4. Slave node (pause after each section)"
echo "5. Exit"
echo
echo -n "Please select the installation type. "

keypress="0"
until [ $keypress = "1" ] || [ $keypress = "2" ] || [ $keypress = "3" ] || [ $keypress = "4" ] || [ $keypress = "5" ]; do
  read -s -n 1 keypress
done

case $keypress in
 1)
   node='master'
   debug=0
   server_hostname=$master_hostname
   server_ip_address_eth1=$master_ip_address_eth1
   server_ip_address_eth0=$master_ip_address_eth0
   liveip=$master_ip_address_eth0
   switchip=$cluster_ip
   ;;
 2) 
   node='master'
   debug=1
   server_hostname=$master_hostname
   server_ip_address_eth1=$master_ip_address_eth1
   server_ip_address_eth0=$master_ip_address_eth0
   liveip=$master_ip_address_eth0
   switchip=$cluster_ip
   ;;
 3)
   node='slave'
   debug=0
   server_hostname=$slave_hostname
   server_ip_address_eth1=$slave_ip_address_eth1
   server_ip_address_eth0=$slave_ip_address_eth0
   liveip=$master_ip_address_eth0
   switchip=$slave_ip_address_eth0
   ;;
 4)
   node='slave'
   debug=1
   server_hostname=$slave_hostname
   server_ip_address_eth1=$slave_ip_address_eth1
   server_ip_address_eth0=$slave_ip_address_eth0
   liveip=$master_ip_address_eth0
   switchip=$slave_ip_address_eth0
   ;;
 5)
   echo
   exit
   ;;
esac

clear
echo "Installation will continue with the following settings:"
echo
echo "Cluster IP address -" $cluster_ip
echo
echo "Node name -" $server_hostname.$domain_name
echo "Node IP address (eth1) -" $server_ip_address_eth1
echo "Node IP address (eth0) -" $server_ip_address_eth0
echo "Node Subnet mask (eth1) -" $subnet_mask_eth1
echo "Node Subnet mask (eth0) -" $subnet_mask_eth0
echo "Node Gateway -" $gateway
echo "Node Primary DNS -" $primary_dns
echo "Node Secondary DNS -" $secondary_dns
echo "Master node name -" $master_hostname.$domain_name
echo "Master node IP address (eth1) -" $master_ip_address_eth1
echo "Master node IP address (eth0) -" $master_ip_address_eth0
echo "Slave node name -" $slave_hostname.$domain_name
echo "Slave node IP address (eth1) -" $slave_ip_address_eth1
echo "Slave node IP address (eth0) -" $slave_ip_address_eth0
echo "DRBD disk partition -" $drbd_disk
echo "DRBD device -" $drbd_device
if [ $debug == 1 ]
then
 echo
 echo "Script will pause after each section has finished."
fi
echo
echo
echo -n "Press 'Y' to proceed, 'N' to exit. "

keypress="a"
until [ $keypress = "y" ] || [ $keypress = "Y" ] || [ $keypress = "n" ] || [ $keypress = "N" ]; do
  read -s -n 1 keypress
done

echo

if [ $keypress = "n" ] || [ $keypress = "N" ]
then
 echo "Installation aborted."
 exit;
fi

echo "Starting Elastix $node node cluster installation."

# First create a backup location for changed files. 

mkdir /CIBackups

# Update all installed packages
yum -y update

echo
echo "Phase 'Update all installed packages' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Install required packages
yum -y install drbd83 drbdlinks kmod-drbd83 OpenIPMI-libs heartbeat-pils openhpi heartbeat heartbeat-stonith
echo
echo "Phase 'Download required packages' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Install the redhat-lsb scripts so that drbdlinks runs correctly 

yum -y install redhat-lsb

echo
echo "Phase 'Install lsb scripts' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Change the hostname 

echo $server_hostname.$domain_name >> /etc/hostname
mv /etc/sysconfig/network /etc/sysconfig/network.backup
cp /etc/sysconfig/network.backup /CIBackups 
sed "s/HOSTNAME=Elastix1.localdomain/HOSTNAME=$server_hostname.$domain_name/g" /etc/sysconfig/network.backup > /etc/sysconfig/network
mv /etc/hosts /etc/hosts.backup
cp /etc/hosts.backup /CIBackups
sed "s/Elastix1.localdomain/$server_hostname.$domain_name/g" /etc/hosts.backup > /etc/hosts
mv /etc/hosts /etc/hosts.backup2
cp /etc/hosts.backup2 /CIBackups
sed "s/Elastix1/$server_hostname/g" /etc/hosts.backup2 > /etc/hosts
/bin/hostname -F /etc/hostname

echo
echo "Phase 'Change hostname' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Configure eth1 

mv /etc/sysconfig/network-scripts/ifcfg-eth1 /CIBackups/ifcfg-eth1.backup
cat << EOF >> /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
ONBOOT=yes
BOOTPROTO=static
IPADDR=$server_ip_address_eth1
NETMASK=$subnet_mask_eth1
EOF

echo
echo "Phase 'Change eth1 settings' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Configure eth0 

mv /etc/sysconfig/network-scripts/ifcfg-eth0 /CIBackups/ifcfg-eth0.backup
cat << EOF >> /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=static
IPADDR=$server_ip_address_eth0
NETMASK=$subnet_mask_eth0
EOF

echo
echo "Phase 'Change eth0 settings' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Update hosts file adding an entries so each node can find each other 

cat << EOF >> /etc/hosts
$master_ip_address_eth1 $master_hostname.$domain_name $master_hostname
$slave_ip_address_eth1 $slave_hostname.$domain_name $slave_hostname
EOF

mv /etc/resolv.conf /CIBackups/resolv.conf.backup
cat << EOF >> /etc/resolv.conf
nameserver $primary_dns
nameserver $secondary_dns
EOF

echo "GATEWAY=$gateway" >> /etc/sysconfig/network

echo
echo "Phase 'Update /etc/hosts, /etc/resolv.conf and adding default gateway' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Restart the network 

service network restart

echo
echo "Phase 'Network restart' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Configure /etc/drbd.conf 

#mv /etc/drbd.conf /CIBackups/drbd.conf.backup
cat << EOF >> /etc/drbd.conf

global { usage-count yes; }

common {
syncer { rate 100M; }
  }

resource drbd0 {
 protocol C;
 handlers { outdate-peer "/usr/lib/heartbeat/drbd-peer-outdater"; }
 startup { wfc-timeout 5; degr-wfc-timeout 120; }
 disk { on-io-error detach; fencing resource-only; }
 net  { after-sb-0pri discard-younger-primary;
        after-sb-1pri consensus;
        after-sb-2pri disconnect;
        cram-hmac-alg sha1;
        shared-secret "3l4st1x";
        }
syncer { rate 100M;}
on $master_hostname.$domain_name {
	device $drbd_device;
	disk $drbd_disk;
	address $master_ip_address_eth1:7788;
	meta-disk internal;
      }
on $slave_hostname.$domain_name {
	device $drbd_device;
	disk $drbd_disk;
	address $slave_ip_address_eth1:7788;
	meta-disk internal;
      }
}
EOF
echo "Phase 'Create drbd.conf' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Update drbd0/share partition from /etc/fstab 

umount /share
mv /etc/fstab /etc/fstab.backup
cp /etc/fstab.backup /CIBackups/fstab.backup
sed '/share/d' /etc/fstab.backup > /etc/fstab

if [ ! -e /share ]
then
 mkdir /share  
fi
cat << EOF >> /etc/fstab
$drbd_device /share ext3 defaults,noauto 0 0
EOF

echo
echo "Phase 'Update drbd0/share partition from /etc/fstab' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Create drbd node 

dd if=/dev/zero bs=1M count=1 of=$drbd_disk; sync
drbdadm create-md drbd0
chgrp haclient /sbin/drbdsetup
chmod o-x /sbin/drbdsetup
chmod u+s /sbin/drbdsetup
chgrp haclient /sbin/drbdmeta
chmod o-x /sbin/drbdmeta
chmod u+s /sbin/drbdmeta
service drbd start

echo
echo "Phase 'Create drbd0 node' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Make primary drbd node

if [ $node == "master" ]
then
 drbdadm -- --overwrite-data-of-peer primary all
# drbdsetup $drbd_device primary -o
# drdbadm state drdb0
 mkfs.ext3 $drbd_device
 mount $drbd_device

 echo
 echo "Phase 'Make primary node' complete."
 if [ $debug == 1 ] 
 then
   echo "Press any key to continue."
   read -n 1 keypress
 fi
 echo
fi

# Stop the services whos data and/or configurations we are moving to the drbd shared disk 

service mysqld stop
service postfix stop
service asterisk stop
service hylafax stop
service httpd stop
service xinetd stop

echo
echo "Phase 'Stop running services' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Create /etc/drbdlinks.conf 

#mv /etc/drbdlinks.conf /CIBackups/drbdlinks.conf.backup
cat << EOF >> /etc/drbdlinks.conf

mountpoint('/share')
link('/usr/lib/asterisk')
link('/var/ftp')
link('/var/log/asterisk')
link('/var/spool/asterisk')
link('/var/spool/vbox')
link('/var/spool/hylafax')
link('/var/db')
link('/var/www')
link('/var/lib/asterisk')
link('/var/lib/dav')
link('/var/lib/mysql')
link('/var/lib/php')
link('/etc/asterisk')
link('/etc/httpd')
link('/etc/php.d')
link('/etc/postfix')
link('/etc/vsftpd')
link('/etc/vsftpd.user_list')
link('/etc/aliases')
link('/etc/aliases.db')
link('/etc/amportal.conf')
link('/etc/dahdi')
link('/etc/dhcpd.conf')
link('/etc/fxotune.conf')
link('/etc/hylafax')
link('/etc/my.cnf')
link('/etc/php.ini')
link('/etc/xinetd.conf')
link('/etc/xinetd.d')
link('/tftpboot')
EOF

echo
echo "Phase 'Create drbdlinks.conf' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

if [ $node == "master" ]
then
 # Backup and move the data creating the entries in /etc/drbdlinks.conf as we go
 cd /share
 # /usr/lib/asterisk
 echo "Moving /usr/lib/asterisk started."
 tar -zcf usr-lib-asterisk.tar.gz /usr/lib/asterisk
 tar -zxf usr-lib-asterisk.tar.gz
 echo "Moving /usr/lib/asterisk completed."
 echo
 # /var/ftp
 echo "Moving /var/ftp started."
 tar -zcf var-ftp.tar.gz /var/ftp
 tar -zxf var-ftp.tar.gz
 echo "Moving /var/ftp completed."
 echo
 # /var/log/asterisk
 echo "Moving /var/log/asterisk started."
 tar -zcf var-log-asterisk.tar.gz /var/log/asterisk
 tar -zxf var-log-asterisk.tar.gz
 echo "Moving /var/log/asterisk completed."
 echo
 # /var/spool/asterisk
 echo "Moving /var/spool/asterisk started."
 tar -zcf var-spool-asterisk.tar.gz /var/spool/asterisk
 tar -zxf var-spool-asterisk.tar.gz
 echo "Moving /var/spool/asterisk completed."
 echo
 # /var/spool/vbox
 echo "Moving /var/spool/vbox started."
 tar -zcf var-spool-vbox.tar.gz /var/spool/vbox
 tar -zxf var-spool-vbox.tar.gz
 echo "Moving /var/spool/vbox completed."
 echo
 # /var/spool/hylafax
 echo "Moving /var/spool/hylafax started."
 tar -zcf var-spool-hylafax.tar.gz /var/spool/hylafax
 tar -zxf var-spool-hylafax.tar.gz
 echo "Moving /var/spool/hylafax completed."
 echo
 # /var/db
 echo "Moving /var/db started."
 tar -zcf var-db.tar.gz /var/db
 tar -zxf var-db.tar.gz
 echo "Moving /var/www completed."
 echo
 # /var/www
 echo "Moving /var/www started."
 tar -zcf var-www.tar.gz /var/www
 tar -zxf var-www.tar.gz
 echo "Moving /var/www completed."
 echo
 # /var/lib/asterisk
 echo "Moving /var/lib/asterisk started."
 tar -zcf var-lib-asterisk.tar.gz /var/lib/asterisk
 tar -zxf var-lib-asterisk.tar.gz
 echo "Moving /var/lib/asterisk completed."
 echo
 # /var/lib/dav
 echo "Moving /var/lib/dav started."
 tar -zcf var-lib-dav.tar.gz /var/lib/dav
 tar -zxf var-lib-dav.tar.gz
 echo "Moving /var/lib/dav completed."
 echo
 # /var/lib/mysql
 echo "Moving /var/lib/mysql started."
 tar -zcf var-lib-mysql.tar.gz /var/lib/mysql
 tar -zxf var-lib-mysql.tar.gz
 echo "Moving /var/lib/mysql completed."
 echo
 # /var/lib/php
 echo "Moving /var/lib/php started."
 tar -zcf var-lib-php.tar.gz /var/lib/php
 tar -zxf var-lib-php.tar.gz
 echo "Moving /var/lib/php completed."
 echo
 # /etc/asterisk
 echo "Moving /etc/asterisk started."
 tar -zcf etc-asterisk.tar.gz /etc/asterisk
 tar -zxf etc-asterisk.tar.gz
 echo "Moving /etc/asterisk completed."
 echo
 # /etc/httpd
 echo "Moving /etc/httpd started."
 tar -zcf etc-httpd.tar.gz /etc/httpd
 tar -zxf etc-httpd.tar.gz
 echo "Moving /etc/httpd completed."
 echo
 # /etc/php.d
 echo "Moving /etc/php.d started."
 tar -zcf etc-php.d.tar.gz /etc/php.d
 tar -zxf etc-php.d.tar.gz
 echo "Moving /etc/php.d completed."
 echo
 # /etc/postfix
 echo "Moving /etc/postfix started."
 tar -zcf etc-postfix.tar.gz /etc/postfix
 tar -zxf etc-postfix.tar.gz
 echo "Moving /etc/postfix completed."
 echo
 # /etc/vsftpd
 echo "Moving /etc/vsftpd started."
 tar -zcf etc-vsftpd.tar.gz /etc/vsftpd
 tar -zxf etc-vsftpd.tar.gz
 echo "Moving /etc/vsftpd completed."
 echo
 # /etc/vsftpd.user_list
 echo "Moving /etc/vsftpd.user_list started."
 tar -zcf etc-vsftpd_user_list.tar.gz /etc/vsftpd.user_list
 tar -zxf etc-vsftpd_user_list.tar.gz
 echo "Moving /etc/vsftpd.user_list completed."
 echo
 # /etc/aliases
 echo "Moving /etc/aliases started."
 tar -zcf etc-aliases.tar.gz /etc/aliases
 tar -zxf etc-aliases.tar.gz
 echo "Moving /etc/aliases completed."
 echo
 # /etc/aliases.db
 echo "Moving /etc/aliases.db started."
 tar -zcf etc-aliases_db.tar.gz /etc/aliases.db
 tar -zxf etc-aliases_db.tar.gz
 echo "Moving /etc/aliases.db completed."
 echo
 # /etc/amportal.conf
 echo "Moving /etc/aliases.db started."
 tar -zcf etc-amportal_conf.tar.gz /etc/amportal.conf
 tar -zxf etc-amportal_conf.tar.gz
 echo "Moving /etc/amportal.conf completed."
 echo
 # /etc/dahdi
 echo "Moving /etc/dahdi started."
 tar -zcf etc-dahdi.tar.gz /etc/dahdi
 tar -zxf etc-dahdi.tar.gz
 echo "Moving /etc/dahdi completed."
 echo
 # /etc/dhcpd.conf
 echo "Moving /etc/dhcpd.conf started."
 tar -zcf etc-dhcpd_conf.tar.gz /etc/dhcpd.conf
 tar -zxf etc-dhcpd_conf.tar.gz
 echo "Moving /etc/dhcpd.conf completed."
 echo
 # /etc/fxotune.conf
 echo "Moving /etc/fxotune.conf started."
 tar -zcf etc-fxotune.conf.tar.gz /etc/fxotune.conf
 tar -zxf etc-fxotune.conf.tar.gz
 echo "Moving /etc/fxotune.conf completed."
 echo
 # /etc/hylafax
 echo "Moving /etc/hylafax started."
 tar -zcf etc-hylafax.tar.gz /etc/hylafax
 tar -zxf etc-hylafax.tar.gz
 echo "Moving /etc/hylafax completed."
 echo
 # /etc/my.cnf
 echo "Moving /etc/my.cnf started."
 tar -zcf etc-my_cnf.tar.gz /etc/my.cnf
 tar -zxf etc-my_cnf.tar.gz
 echo "Moving /etc/my.cnf completed."
 echo
 # /etc/php.ini
 echo "Moving /etc/php.ini started."
 tar -zcf etc-php_ini.tar.gz /etc/php.ini
 tar -zxf etc-php_ini.tar.gz
 echo "Moving /etc/php.ini completed."
 echo
 # /etc/xinetd.conf
 echo "Moving /etc/xinetd.conf started."
 tar -zcf etc-xinetd_conf.tar.gz /etc/xinetd.conf
 tar -zxf etc-xinetd_conf.tar.gz
 echo "Moving /etc/xinetd.conf completed."
 echo
 # /etc/xinetd.d
 echo "Moving /etc/xinetd.d started."
 tar -zcf etc-xinetd_d.tar.gz /etc/xinetd.d
 tar -zxf etc-xinetd_d.tar.gz
 echo "Moving /etc/xinetd.d completed."
 echo
 # /tftpboot
 echo "Moving /tftpboot started."
 tar -zcf tftpboot.tar.gz /tftpboot
 tar -zxf tftpboot.tar.gz
 echo "Moving /tftpboot completed."
 echo

 # First for sanity sake we stash the zips away should things go pear shaped.
 
 mv /share/*.tar.gz /CIBackups
 
 # Fix some symlinks for /etc/httpd
 rm -fr /share/etc/httpd/logs
 rm -fr /share/etc/httpd/modules
 rm -fr /share/etc/httpd/run

 ln -s /var/log/httpd /share/etc/httpd/logs
 ln -s /usr/lib/httpd/modules /share/etc/httpd/modules
 ln -s /var/run /share/etc/httpd/run

 echo
 echo "Phase 'Data move' complete."
 if [ $debug == 1 ] 
 then
   echo "Press any key to continue."
   read -n 1 keypress
 fi
 echo
fi

# Delete replicated data from original location

rm -fr /usr/lib/asterisk
rm -fr /var/ftp
rm -fr /var/log/asterisk
rm -fr /var/spool/asterisk
rm -fr /var/spool/vbox
rm -fr /var/spool/hylafax
rm -fr /var/db
rm -fr /var/www
rm -fr /var/lib/asterisk
rm -fr /var/lib/dav
rm -fr /var/lib/mysql
rm -fr /var/lib/php
rm -fr /etc/asterisk
rm -fr /etc/httpd/
rm -fr /etc/php.d
rm -fr /etc/postfix
rm -fr /etc/vsftpd
rm -fr /etc/vsftpd.user_list
rm -fr /etc/aliases
rm -fr /etc/aliases.db
rm -fr /etc/amportal.conf
rm -fr /etc/dahdi
rm -fr /etc/dhcpd.conf
rm -fr /etc/fxotune.conf
rm -fr /etc/hylafax
rm -fr /etc/my.cnf
rm -fr /etc/php.ini
rm -fr /etc/xinetd.conf
rm -fr /etc/xinetd.d
rm -fr /tftpboot

# Making symlinks from partition

ln -s /usr/lib64/httpd  /usr/lib/httpd
ln -s /share/usr/lib/asterisk  /usr/lib/asterisk
ln -s /share/var/ftp      /var/ftp
ln -s /share/var/log/asterisk  /var/log/asterisk
ln -s /share/var/spool/asterisk  /var/spool/asterisk
ln -s /share/var/spool/vbox  /var/spool/vbox
ln -s /share/var/spool/hylafax  /var/spool/hylafax
ln -s /share/var/db    /var/db
ln -s /share/var/www    /var/www
ln -s /share/var/lib/asterisk  /var/lib/asterisk
ln -s /share/var/lib/dav  /var/lib/dav
ln -s /share/var/lib/mysql  /var/lib/mysql
ln -s /share/var/lib/php  /var/lib/php
ln -s /share/etc/asterisk  /etc/asterisk
ln -s /share/etc/httpd    /etc/httpd
ln -s /share/etc/php.d    /etc/php.d
ln -s /share/etc/postfix  /etc/postfix
ln -s /share/etc/vsftpd    /etc/vsftpd
ln -s /share/etc/vsftpd.user_list /etc/vsftpd.user_list
ln -s /share/etc/aliases  /etc/aliases
ln -s /share/etc/aliases.db  /etc/aliases.db
ln -s /share/etc/amportal.conf  /etc/amportal.conf
ln -s /share/etc/dahdi    /etc/dahdi
ln -s /share/etc/dhcpd.conf  /etc/dhcpd.conf
ln -s /share/etc/fxotune.conf  /etc/fxotune.conf
ln -s /share/etc/hylafax  /etc/hylafax
ln -s /share/etc/my.cnf    /etc/my.cnf
ln -s /share/etc/php.ini  /etc/php.ini
ln -s /share/etc/xinetd.conf  /etc/xinetd.conf
ln -s /share/etc/xinetd.d  /etc/xinetd.d
ln -s /share/tftpboot    /tftpboot

echo
echo "Phase 'Deleting replicated data from original location' complete."
if [ $debug == 1 ]
then
  echo "Press any key to continue."
  read -n 1 keypress
fi
echo 


# Configure /etc/ha.d/ha.cf 

#mv /etc/ha.d/ha.cf /CIBackups/ha.cf.backup
cat << EOF >> /etc/ha.d/ha.cf

debugfile /var/log/ha-debug
logfile /var/log/ha-log
logfacility local0
keepalive 1 		# Interval between heartbeat (HB«») packets.
deadtime 10 		# How quickly HB determines a dead node.
warntime 5 		# Time HB will issue a late HB.
initdead 120 		# Time delay needed by HB to report a dead node.
udpport 694 		# UDP port HB uses to communicate between nodes.
bcast eth1 		# Which interface to use for HB packets.
auto_failback on 	# Auto promotion of primary node upon return to cluster.
node $master_hostname.$domain_name
node $slave_hostname.$domain_name
EOF

echo
echo "Phase 'Create ha.cf' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Configure /etc/ha.d/haresources 

#mv /etc/ha.d/haresources /CIBackups/haresources.backup
cat << EOF >> /etc/ha.d/haresources

$master_hostname.$domain_name drbddisk::drbd0 Filesystem::$drbd_device::/share::ext3 drbdip drbdlinks mysqld postfix httpd amportal xinetd hylafax openfire
EOF

echo
echo "Phase 'Create haresources' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi

echo

# Configure /etc/ha.d/authkeys 

mv /etc/ha.d/authkeys /CIBackups/authkeys.backup
cat << EOF >> /etc/ha.d/authkeys

auth 1
1 crc
EOF

chmod 600 /etc/ha.d/authkeys

echo
echo "Phase 'Create authkeys' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Configure /etc/init.d/amportal

cat << EOF >> /etc/init.d/amportal
#! /bin/sh
#
# Source function library.
. /etc/rc.d/init.d/functions
RETVAL=0
PROCNAME=portal
# See how we were called.
case "\$1" in
start)
/usr/sbin/amportal start
RETVAL=0
echo
;;
stop)
/usr/sbin/amportal stop
RETVAL=0
echo
;;
status)
status \$PROCNAME
RETVAL=\$?
;;
restart|reload)
\$0 stop
\$0 start
RETVAL=\$?
;;
*)
echo "Usage: amportal {start|stop|status|restart}"
exit 1
esac
exit \$RETVAL
EOF
chmod 755 /etc/init.d/amportal
chkconfig --add amportal

echo
echo "Phase 'Create amportal init script' complete."
if [ $debug == 1 ]
then
  echo "Press any key to continue."
  read -n 1 keypress
fi
echo

# Configure /etc/init.d/drbdip

cat << EOF >> /etc/init.d/drbdip
#!/bin/sh
# drbdip daemon
# chkconfig: 345 20 80
# description: start: change ip from 173 to 172, stop change ip from 172 to 173
# processname: drbdip

DAEMON_PATH="/"

DAEMON=drbdip
DAEMONOPTS="-my opts"
NAME=drbdip

case "\$1" in
start)
	printf "%-50s" "Starting \$NAME..."
	ifconfig eth0 $liveip
	route add default gw $gateway
	ping -c 2 google.com > /dev/null 2>&1
	printf "%s\n" "Ok"
    exit 0
;;
status)
        printf "%-50s" "Checking \$NAME..."
        ifconfig eth0
	    exit 0

;;
stop)
    printf "%-50s" "Starting \$NAME..."
	ifconfig eth0 $switchip    
	printf "%s\n" "Ok"
	ping -c 2 google.com > /dev/null 2>&1
	route add default gw gateway
    exit 0

;;

restart)
  	\$0 stop
  	\$0 start
    exit 0

;;

*)
        echo "Usage: \$0 {status|start|stop|restart}"
        exit 1
esac
EOF
chmod 755 /etc/init.d/drbdip
chkconfig --add drbdip

echo
echo "Phase 'Create drbdip init script' complete."
if [ $debug == 1 ]
then
  echo "Press any key to continue."
  read -n 1 keypress
fi
echo



# Remove amportal startup configuration from /etc/rc.local 

mv /etc/rc.local /etc/rc.local.backup
cp /etc/rc.local.backup /CIBackups/rc.local.backup
sed '/amportal/d' /etc/rc.local.backup > /etc/rc.local

echo
echo "Phase 'Remove amportal startup configuration from rc.local' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Change service startup and shutdown in init scripts 

chkconfig --levels 345 amportal	off
chkconfig --levels 345 asterisk	off
chkconfig --levels 345 httpd	off
chkconfig --levels 345 hylafax	off
chkconfig --levels 345 mysqld	off
chkconfig --levels 345 postfix	off
chkconfig --levels 345 xinetd	off
chkconfig --levels 345 drbdip	off
chkconfig --levels 345 openfire off

chkconfig --levels 345 heartbeat on

service drdb restart
service heartbeat restart

echo
echo "Phase 'Change service runlevels' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo

# Create a script for ha-log quick access 

echo "tail -f /var/log/ha-log" >> /usr/bin/ha
chmod a+x /usr/bin/ha

echo
echo "Phase 'Create ha-log quick access' complete."
if [ $debug == 1 ]
then
 echo "Press any key to continue."
 read -n 1 keypress
fi
echo


if [ $node == "slave" ]
then
 # Test connectivity between the nodes

 echo
 echo "Phase 'Testing connectivity' complete."
 if [ $debug == 1 ] 
 ping -c 5 $master_hostname.$domain_name
 ping -c 5 $slave_hostname.$domain_name
 then
   echo "Press any key to continue."
   read -n 1 keypress
 fi
 echo
fi

# Start the heartbeat service 

service heartbeat start

clear
echo "Elastix $node node cluster installation finished."

echo
echo "Showing /etc/log/ha-log (Press Ctrl-C to quit)"
echo
/usr/bin/ha

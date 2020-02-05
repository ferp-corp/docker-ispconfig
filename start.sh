#!/bin/bash

envsubst < /root/autoinstall.ini > /tmp/ispconfig3_install/install/autoinstall.ini
envsubst < /root/authmysqlrc.ini > /etc/courier/authmysqlrc

echo $isp_hostname > /etc/mailname

cd /tmp/ispconfig3_install/install/

if [ -f /usr/local/ispconfig/interface/lib/config.inc.php ]; 
then
	/wait-for-it.sh master:3306 -- php -q update.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini
else
	/wait-for-it.sh master:3306 -- php -q install.php --autoinstall=/tmp/ispconfig3_install/install/autoinstall.ini
fi

sed -i "s/^hosts .*$/hosts = $isp_mysql_hostname/g" /etc/postfix/mysql-virtual_outgoing_bcc.cf
sed -i "s/^myhostname = .*$/myhostname = $isp_hostname/g" /etc/postfix/main.cf

echo "UPDATE mysql.user SET Host = '%' WHERE User like 'ispc%';" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password
echo "UPDATE mysql.db SET Host = '%' WHERE User like 'ispc%';" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password
echo "FLUSH PRIVILEGES;" | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password

# Bugfix ISPconfig mysql error
echo "ALTER TABLE dbispconfig.sys_user MODIFY passwort VARCHAR(140);"  | mysql -u root -h$isp_mysql_hostname -p$isp_mysql_root_password


mkdir -p /etc/courier/shared/index
chmod -R 770 /etc/courier/shared

rm -rf /var/run/saslauthd
ln -sfn /var/spool/postfix/var/run/saslauthd /var/run/saslauthd

screenfetch

/etc/init.d/clamav-daemon start

if [ "$isp_enable_mail" == "y" ];
then
  /etc/init.d/courier-authdaemon start
fi

if [ "$isp_enable_dns" == "y" ];
then
  /etc/init.d/bind9 start
fi

if [ "$isp_enable_nginx" == "y" ];
then
  /etc/init.d/php7.2-fpm start
fi

if [ "$isp_enable_apache" == "y" ];
then
  /etc/init.d/php7.2-fpm start
fi

unset isp_mysql_root_password
unset isp_mysql_ispconfig_password
unset isp_mysql_master_root_password
unset isp_admin_password


/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

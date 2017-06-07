#!/bin/bash
# pg_dump tables

PGBINDIR="/opt/pgsql/bin"
BACKUP_FILE="/web/data_bak"
BACKUP_SERVER="10.0.1.113"
PSQL_USER="postgres"
PORT="5432"
DATE=`date +%F`
TIME=`date +%F-%H-%M-%S`
DATALIST="/tmp/datalist_$TIME"
TABLELIST="/tmp/tablelist_$TIME"
HOSTNAME=`hostname | sed 's/eln//g'`
MAILLIST="yezhengjie@21tb.com hebaofeng@21tb.com"

#服务器备份目录
su - postgres -c "ssh postgres@$BACKUP_SERVER 'if [ ! -d /web/pgbak/"$HOSTNAME"bak ];then mkdir -p /web/pgbak/"$HOSTNAME"bak ;fi'"

#完整备份
$PGBINDIR/pg_dumpall -U$PSQL_USER -p$PORT | gzip > $BACKUP_FILE/$HOSTNAME-$DATE.sql.gz
chown postgres.postgres $BACKUP_FILE/$HOSTNAME-$DATE.sql.gz

if [ $? -eq 0 ];then
	su - postgres -c "ssh postgres@$BACKUP_SERVER 'find /web/pgbak/"$HOSTNAME"bak/ -name "*.sql.gz" -mtime +1 -exec rm -f {} \; '" 
	su - postgres -c "scp $BACKUP_FILE/$HOSTNAME-$DATE.sql.gz postgres@$BACKUP_SERVER:/web/pgbak/"$HOSTNAME"bak/"
	rm -r $BACKUP_FILE/$HOSTNAME-$DATE.sql.gz
else
	sendEmail -f eln@public.21tb.com -t $MAILLIST -s mail.public.21tb.com -u "$DATE $HOSTNAME 备份失败" -xu eln@public.21tb.com -xp 09870987 -m "$DATE $HOSTNAME 备份失败"
fi

#表备份
mkdir -p $BACKUP_FILE/$DATE
$PGBINDIR/psql -U$PSQL_USER -p$PORT -c "\l" | grep UTF-8 | awk '{print $1}'| grep -v template | grep -v postgres > $DATALIST
echo "start dump tables..."

for DATABASE in `cat $DATALIST`
do
	mkdir -p $BACKUP_FILE/$DATE/$DATABASE
	$PGBINDIR/psql -U$PSQL_USER -p$PORT $DATABASE -c "\d" | grep table | awk '{print $3}' > $TABLELIST
	for TABLE in `cat $TABLELIST`
	do
		$PGBINDIR/pg_dump -U$PSQL_USER -p$PORT $DATABASE -t $TABLE | gzip > $BACKUP_FILE/$DATE/$DATABASE/$TABLE.sql.gz
	done
done
echo "dump tables finshed"

cd $BACKUP_FILE
chown postgres.postgres $DATE -R
tar cvf $HOSTNAME-$DATE.tar $DATE >> /dev/null
chown postgres.postgres $HOSTNAME-$DATE.tar

if [ $? -eq 0 ];then
	su - postgres -c "ssh postgres@$BACKUP_SERVER 'find /web/pgbak/"$HOSTNAME"bak/ -name "*.tar" -mtime +7 -exec rm -f {} \; '" 
	su - postgres -c "scp $BACKUP_FILE/$HOSTNAME-$DATE.tar postgres@$BACKUP_SERVER:/web/pgbak/"$HOSTNAME"bak/"
else
	sendEmail -f eln@public.21tb.com -t $MAILLIST -s mail.public.21tb.com -u "$DATE $HOSTNAME 表备份失败" -xu eln@public.21tb.com -xp 09870987 -m "$DATE $HOSTNAME 表备份失败"
fi

rm -fr $HOSTNAME-`date -d '1 day ago' +%F`.tar

rm -fr $BACKUP_FILE/$DATE
rm -fr $DATALIST $TABLELIST
echo "backup is ok!"


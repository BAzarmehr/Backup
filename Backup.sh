#===============================================================================
#
#          FILE:  backup.sh
# 
#         USAGE:  ./backup.sh 
# 
#   DESCRIPTION:  
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Behzad Azarmehr (), Behzad.Azarmehr@Gmail.com
#       COMPANY:  Sazman Melli Javanan
#       VERSION:  0.3 Beta
#       CREATED:  08/29/2011 11:34:00 PM IRDT
#      REVISION:  2013 17 March 09:57:04 PM
#===============================================================================

LOG_FILE='/var/log/backup-script'
CONF_FILE='/etc/portal/main.conf'
MKDIR='/bin/mkdir'
TAR='/bin/tar'
RM='/bin/rm'
CP='/bin/cp'
GZIP='/bin/gzip'
MYSQL='/usr/bin/mysql'
MD5SUM='/usr/bin/md5sum'
MYSQLDUMP='/usr/bin/mysqldump'

DATE="`date +%Y-%m-%d`"
BACKUP_HOME='.'
#BACKUP_HOME='/backup/daily'
BACKUP_DIR="$BACKUP_HOME/$DATE"


#===============================================================================
function log ()
{
        TITLE=$1
        case $2 in
        1)
                MSG='Could not open main.conf file.'
                ;;
        2)
                MSG="Could not connect to MySQL database."
                ;;
        3)
                MSG="Back up From Webpage(Parameters_sbank)."
                ;;
        4)
                MSG="Back up From Webpage(Portlets)."
                ;;
        5)
                MSG="Back up From Webpage(Parameters)."
                ;;
        6)
                MSG="Dump fom database javan_db_base."
                ;;
        7)
                MSG="Dump fom database javanan_portal."
                ;;
				
		8)
                MSG="Uplod to Server Sazman."
                ;;
        *)
                return 1
        esac

        echo `date +%Y-%m-%d/%H-%M-%S`":" $TITLE ":" $MSG >> $LOG_FILE 2>&1
}
#===============================================================================
function get_conf ()
{
        if [ -f $CONF_FILE ]; then
                DBUSER=`   grep "^DBUSER = "    $CONF_FILE | awk -F "\"" '{print $2}'`
                DBPASS=`   grep "^DBPASSWD = "  $CONF_FILE | awk -F "\"" '{print $2}'`
        else
		log "Error" 1
        fi
}
#===============================================================================
function check_connect_db ()
{
        local retval=`$MYSQL -u $DBUSER -p"$DBPASS" -e "select 'OK'" 2>&1`
        local status=`echo $retval | awk '{print $1}'`
	if [ "$status" != "OK" ]; then
                log "Error" 2
                exit 1
        fi

}
#===============================================================================
function make_folder()
{
	mkdir -p $BACKUP_DIR 2>&1
}
#===============================================================================
function cleanup_backup_folder()
{
	rm $BACKUP_FOLDER/web_backup.snar
}
#===============================================================================
function check_folder ()
{
	BACKUP_STATUS=`cat backup | awk '{print $1}'`
	BACKUP_FOLDER=`cat backup | awk '{print $2}'`
	if [ $BACKUP_STATUS -eq 0 ];then
		make_folder
		BACKUP_STATUS=$(($BACKUP_STATUS+1))
		echo -e "$BACKUP_STATUS\t$BACKUP_DIR" > backup
		echo "$BACKUP_DIR" >> backup_history
		backup_web_full
	elif [ $BACKUP_STATUS -gt 6 ];then
		echo 0 > backup
		cleanup_backup_folder # For prevent rewrite web_backup.snar
		#check_folder
	else
		BACKUP_STATUS=$(($BACKUP_STATUS+1))
		echo -e "$BACKUP_STATUS\t$BACKUP_FOLDER" > backup
		backup_web_incremental
	fi
}
#===============================================================================
function found_oldest_backup()
{
	if [ -f backup_history ]; then
		OLDEST_BACKUP=`head -n 1 backup_history`
		rm -r $OLDEST_BACKUP
		if [ $? == 0 ];then
			echo "I Remove oldest backup Successfully :)"
			sed -i '1d' backup_history
			check_folder
		else
			echo "The Space is not enough to backup,sorry :("
			exit
		fi
	fi
}
#===============================================================================
function check_diskspace ()
{
	DISKSPACE=`df -h | grep -i home | awk '{print $5}'`
	DISKSPACE=`echo "${DISKSPACE%?}"`
	
	if [ $DISKSPACE -gt 30 ];then
		echo "Warning!!"
		echo "We need Clean up some Backup"
		found_oldest_backup
	else
		check_folder
	fi
}
#===============================================================================
function backup_web_full()
{
	cd .
	tar --listed-incremental $BACKUP_DIR/web_backup.snar -czpf $BACKUP_DIR/web_backup_full.tar.gz web
	if [ $? == 0 ];then
		echo "wow. i get full backup"
		`$MD5SUM $BACKUP_DIR/web_backup_full.tar.gz > $BACKUP_DIR/md5sum_full`
	else
		echo "sorry, i can't get backup :("
	fi
}	
#===============================================================================
function backup_web_incremental()
{
	cd .
	tar --listed-incremental $BACKUP_FOLDER/web_backup.snar -czpf $BACKUP_FOLDER/web_backup_incremental_$BACKUP_STATUS.tar.gz web
	if [ $? == 0 ];then
		echo "wow. i get incremental backup $BACKUP_STATUS"
		`$MD5SUM $BACKUP_FOLDER/web_backup_incremental_$BACKUP_STATUS.tar.gz > $BACKUP_FOLDER/md5sum_incremental_$BACKUP_STATUS`
	else
		echo "sorry, i can't get backup :("
	fi
}	
#===============================================================================
function backup_db()
{
	$MYSQLDUMP -u$DBUSER -p"$DBPASS" --routines --skip-lock-tables javan_db_base  | gzip -9 >  $BACKUP_DIR/db_portal_$DATE.sql.gz; # Main Portal 
	if [ $? == 0 ];then
		log "Success" 6
	else
		log "Error" 6
	fi
		
	$MYSQLDUMP -u$DBUSER -p"$DBPASS" --routines --skip-lock-tables javanan_portal  | gzip -9 > $BACKUP_DIR/db_subportal_$DATE.sql.gz; # subportal
	if [ $? == 0 ];then
		log "Success" 7
	else
		log "Error" 7
	fi
}
#===============================================================================
function main()
{
	check_diskspace
}
#==============================================================================
main

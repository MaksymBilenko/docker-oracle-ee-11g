#!/bin/bash
set -e

# Prevent owner issues on mounted folders
echo "Preparing oracle installer."
chown -R oracle:dba /u01/app/oracle
rm -f /u01/app/oracle/product
ln -s /u01/app/oracle-product /u01/app/oracle/product

#Run Oracle root scripts
echo "Running root scripts."
/u01/app/oraInventory/orainstRoot.sh 2>&1
echo | /u01/app/oracle/product/11.2.0/EE/root.sh 2>&1 || true

impdp () {
	set +e
	DUMP_FILE=$(basename "$1")
	DUMP_NAME=${DUMP_FILE%.dmp} 
	cat > /tmp/impdp.sql << EOL
-- Impdp User
CREATE USER IMPDP IDENTIFIED BY IMPDP;
ALTER USER IMPDP ACCOUNT UNLOCK;
GRANT dba TO IMPDP WITH ADMIN OPTION;
-- New Scheme User
create or replace directory IMPDP as '/docker-entrypoint-initdb.d';
create tablespace $DUMP_NAME datafile '/u01/app/oracle/oradata/$DUMP_NAME.dbf' size 1000M autoextend on next 100M maxsize unlimited;
create user $DUMP_NAME identified by $DUMP_NAME default tablespace $DUMP_NAME;
alter user $DUMP_NAME quota unlimited on $DUMP_NAME;
alter user $DUMP_NAME default role all;
grant all to $DUMP_NAME;
exit;
EOL

	su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba @/tmp/impdp.sql"
	su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/impdp IMPDP/IMPDP directory=IMPDP dumpfile=$DUMP_FILE $IMPDP_OPTIONS"
	#Disable IMPDP user
	echo -e 'ALTER USER IMPDP ACCOUNT LOCK;\nexit;' | su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba"
	set -e
}

case "$1" in
	'')
		#Check for mounted database files
		if [ "$(ls -A /u01/app/oracle/oradata)" ]; then
			echo "found files in /u01/app/oracle/oradata Using them instead of initial database"
			echo "EE:$ORACLE_HOME:N" >> /etc/oratab
			chown oracle:dba /etc/oratab
			chown 664 /etc/oratab
			rm -rf /u01/app/oracle-product/11.2.0/EE/dbs
			ln -s /u01/app/oracle/dbs /u01/app/oracle-product/11.2.0/EE/dbs
			#Startup Database
			su oracle -c "/u01/app/oracle/product/11.2.0/EE/bin/tnslsnr &"
			su oracle -c 'echo startup\; | $ORACLE_HOME/bin/sqlplus -S / as sysdba'
		else
			echo "Database not initialized. Initializing database."
			export IMPORT_FROM_VOLUME=true

			if [ -z "$CHARACTER_SET" ]; then
				export CHARACTER_SET="AL32UTF8"
			fi

			mv /u01/app/oracle-product/11.2.0/EE/dbs /u01/app/oracle/dbs
			ln -s /u01/app/oracle/dbs /u01/app/oracle-product/11.2.0/EE/dbs

			echo "Starting tnslsnr"
			su oracle -c "/u01/app/oracle/product/11.2.0/EE/bin/tnslsnr &"
			#create DB for SID: EE
			echo "Running initialization by dbca"
			su oracle -c "$ORACLE_HOME/bin/dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbname EE.oracle.docker -sid EE -responseFile NO_VALUE -characterSet $CHARACTER_SET -totalMemory $DBCA_TOTAL_MEMORY -emConfiguration LOCAL -dbsnmpPassword oracle -sysPassword oracle -systemPassword oracle"
		fi

		if [ $WEB_CONSOLE == "true" ]; then
			echo 'Starting web management console'
			su oracle -c 'echo EXEC DBMS_XDB.sethttpport\(8080\)\; | $ORACLE_HOME/bin/sqlplus -S / as sysdba'
		else
			echo 'Disabling web management console'
			su oracle -c 'echo EXEC DBMS_XDB.sethttpport\(0\)\; | $ORACLE_HOME/bin/sqlplus -S / as sysdba'
		fi

		if [ $IMPORT_FROM_VOLUME ]; then
			echo "Starting import from '/etc/entrypoint-initdb.d':"

			for f in /etc/entrypoint-initdb.d/*; do
				echo "found file $f"
				case "$f" in
					*.sh)     echo "[IMPORT] $0: running $f"; . "$f" ;;
					*.sql)    echo "[IMPORT] $0: running $f"; echo "exit" | su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba @$f"; echo ;;
					*)        echo "[IMPORT] $0: ignoring $f" ;;
				esac
				echo
			done

			echo "Import finished"
			echo
		else
			echo "[IMPORT] Not a first start, SKIPPING Import from Volume '/docker-entrypoint-initdb.d'"
			echo "[IMPORT] If you want to enable import at any state - add 'IMPORT_FROM_VOLUME=true' variable"
			echo
		fi

		echo "Database ready to use. Enjoy! ;)"

		##
		## Workaround for graceful shutdown.
		##
		while [ "$END" == '' ]; do
			sleep 1
			trap "su oracle -c 'echo shutdown immediate\; | $ORACLE_HOME/bin/sqlplus -S / as sysdba'" INT TERM
		done
		;;

	*)
		echo "Database is not configured. Please run '/entrypoint.sh' if needed."
		exec "$@"
		;;
esac

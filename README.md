Oracle Enterprise Edition 11g Release 2
============================

Oracle Enterprise Edition 11g Release 2 on Oracle Linux

[![asciicast](https://asciinema.org/a/45878.png)](https://asciinema.org/a/45878)

### Installation

    docker pull loliconneko/oracle-ee-11g

Run with 8080 and 1521 ports opened:

    docker run -d -p 8080:8080 -p 1521:1521 loliconneko/oracle-ee-11g

Run with data on host and reuse it:

    docker run -d -p 8080:8080 -p 1521:1521 -v /my/oracle/data:/u01/app/oracle loliconneko/oracle-ee-11g

Run with Custom DBCA_TOTAL_MEMORY (in Mb):

    docker run -d -p 8080:8080 -p 1521:1521 -v /my/oracle/data:/u01/app/oracle -e DBCA_TOTAL_MEMORY=1024 loliconneko/oracle-ee-11g

Connect database with following setting:

    hostname: localhost
    port: 1521
    sid: EE
    service name: EE.oracle.docker
    username: system
    password: oracle

To connect using sqlplus:

<pre>
sqlplus system/oracle@//localhost:1521/EE.oracle.docker
</pre>

Password for SYS & SYSTEM:

    oracle

Apex install up to v 5.*

    docker run -it --rm --volumes-from ${DB_CONTAINER_NAME} --link ${DB_CONTAINER_NAME}:oracle-database -e PASS=YourSYSPASS sath89/apex install
Details could be found here: https://github.com/MaksymBilenko/docker-oracle-apex

Connect to Oracle Enterprise Management console with following settings:

    http://localhost:8080/em
    user: sys
    password: oracle
    connect as sysdba: true

By Default web management console is enabled. To disable add env variable:

    docker run -d -e WEB_CONSOLE=false -p 1521:1521 -v /my/oracle/data:/u01/app/oracle loliconneko/oracle-ee-11g
    #You can Enable/Disable it on any time

Start with additional init scripts or dumps:

    docker run -d -p 1521:1521 -v /my/oracle/data:/u01/app/oracle -v /my/oracle/init/SCRIPTSorSQL:/etc/entrypoint-initdb.d loliconneko/oracle-ee-11g
By default Import from `/etc/entrypoint-initdb.d` enabled only if you are initializing database(1st run). If you need to run import at any case - add `-e IMPORT_FROM_VOLUME=true`
**In case of using DMP imports dump file should be named like ${IMPORT_SCHEME_NAME}.dmp**
**User credentials for imports are  ${IMPORT_SCHEME_NAME}/${IMPORT_SCHEME_NAME}**

Forked from https://github.com/MaksymBilenko/docker-oracle-ee-11g
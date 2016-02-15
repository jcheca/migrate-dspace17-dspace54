#!/bin/bash

  # need to install maven3
  wget http://ppa.launchpad.net/natecarlson/maven3/ubuntu/pool/main/m/maven3/maven3_3.2.1-0~ppa1_all.deb
  dpkg -i  maven3_3.2.1-0~ppa1_all.deb
  ln -s /usr/share/maven3/bin/mvn /usr/bin/mvn
  rm maven3_3.2.1-0~ppa1_all.deb

  # created user
  useradd -m dspace
  echo "dspace:admin"|chpasswd
  mkdir /dspace
  chown dspace /dspace

  #conf tomcat7 for dspace
  a=$(cat /etc/tomcat8/server.xml | grep -n "</Host>"| cut -d : -f 1 )
  sed -i "$((a-1))r /tmp/dspace_tomcat8.conf" /etc/tomcat8/server.xml

  mkdir /build
        chmod -R 770 /build
        cd /build
        wget https://github.com/DSpace/DSpace/releases/download/dspace-3.5/dspace-3.5-src-release.tar.gz
        tar -zxf dspace-3.5-src-release.tar.gz
        rm dspace-3.5-src-release.tar.gz
    
        cd /build/dspace-3.5-src-release/dspace
        mvn package
      
        # fix problem relate to postgresql
        cd /var/lib/postgresql/9.4/main
        cp /etc/ssl/certs/ssl-cert-snakeoil.pem server.crt
        cp /etc/ssl/private/ssl-cert-snakeoil.key server.key
        chown postgres *
        chmod 640 server.crt server.key
        cd /build/dspace-3.5-src-release
        
    #conf database before build and installation of dspace
        POSTGRESQL_BIN=/usr/lib/postgresql/9.4/bin/postgres
        POSTGRESQL_CONFIG_FILE=/etc/postgresql/9.4/main/postgresql.conf
        
        mkdir -p /var/run/postgresql/9.4-main.pg_stat_tmp
        chown postgres /var/run/postgresql/9.4-main.pg_stat_tmp
        chgrp postgres /var/run/postgresql/9.4-main.pg_stat_tmp
        
        /sbin/setuser postgres $POSTGRESQL_BIN --single \
                --config-file=$POSTGRESQL_CONFIG_FILE \
              <<< "UPDATE pg_database SET encoding = pg_char_to_encoding('UTF8') WHERE datname = 'template1'" &>/dev/null

        /sbin/setuser postgres $POSTGRESQL_BIN --single \
                --config-file=$POSTGRESQL_CONFIG_FILE \
                  <<< "CREATE USER dspace WITH SUPERUSER;" &>/dev/null
        /sbin/setuser postgres $POSTGRESQL_BIN --single \
                --config-file=$POSTGRESQL_CONFIG_FILE \
                <<< "ALTER USER dspace WITH PASSWORD 'dspace';" &>/dev/null
                
        echo "local all dspace md5" >> /etc/postgresql/9.4/main/pg_hba.conf
        /sbin/setuser postgres /usr/lib/postgresql/9.4/bin/postgres -D  /var/lib/postgresql/9.4/main -c config_file=/etc/postgresql/9.4/main/postgresql.conf >>/var/log/postgresd.log 2>&1 &
        sleep 10s
        /sbin/setuser dspace createdb -U dspace -E UNICODE dspace 
        
        # build dspace and install
        # cd /build/dspace-3.5-src-release/dspace/target/dspace-installer
        cd /build/dspace-3.5-src-release/dspace/target/dspace-3.5-build
        ant fresh_install
        chown tomcat8:tomcat8 /dspace -R
        killall postgres
        sleep 10s

  apt-get clean
  rm -rf /build
  rm -rf /tmp/* /var/tmp/*
  rm -rf /var/lib/apt/lists/*

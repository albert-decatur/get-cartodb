## Installing CartoDB on Ubuntu Server 12.04

### Get CartoDB Rails application source

    sudo apt-get update

    sudo apt-get install git

    cd ~
    git clone --recursive https://github.com/CartoDB/cartodb20.git
    cd cartodb20/
    git checkout master

### Configure APT sources

    sudo apt-get install software-properties-common python-software-properties

    sudo add-apt-repository ppa:cartodb/gis
    sudo add-apt-repository ppa:cartodb/nodejs
    sudo add-apt-repository ppa:cartodb/redis
    sudo add-apt-repository  ppa:cartodb/postgresql
    sudo add-apt-repository ppa:mapnik/v2.2.0

In /etc/apt/sources.list.d/ adjust sources to "precise" voor gis, nodejs and postgresql, and to "lucid" for redis.

    sudo apt-get update

### Install PostgreSQL, PostGIS, dependencies

    sudo apt-get install unp zip libgeos-c1 libgeos-dev gdal-bin libgdal1-dev libjson0 python-simplejson libjson0-dev proj-bin proj-data libproj-dev

    sudo apt-get install postgresql-9.1 postgresql-client-9.1 postgresql-contrib-9.1 postgresql-server-dev-9.1

    sudo apt-get install postgresql-plpython-9.1

    sudo apt-get install make

#### PostGIS and template

    cd /usr/local/src
    sudo wget http://download.osgeo.org/postgis/source/postgis-2.0.2.tar.gz
    sudo tar xzf postgis-2.0.2.tar.gz
    cd postgis-2.0.2
    ./configure --with-raster --with-topology
    make
    sudo make install

create a script template_postgis.sh containing:

    #!/usr/bin/env bash
    POSTGIS_SQL_PATH=`pg_config --sharedir`/contrib/postgis-2.0
    createdb -E UTF8 template_postgis
    createlang -d template_postgis plpgsql
    psql -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='template_postgis'"
    psql -d template_postgis -f $POSTGIS_SQL_PATH/postgis.sql
    psql -d template_postgis -f $POSTGIS_SQL_PATH/spatial_ref_sys.sql
    psql -d template_postgis -f $POSTGIS_SQL_PATH/legacy.sql
    psql -d template_postgis -f $POSTGIS_SQL_PATH/rtpostgis.sql
    psql -d template_postgis -f $POSTGIS_SQL_PATH/topology.sql
    psql -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;"
    psql -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"


Make executable:

    chmod +x template_postgis.sh

Run script as user postgres:

    sudo -u postgres -i
    cd to correct directory
    ./template_postgis.sh

(If you get an error message because the default encoding is not UTF8, see https://wiki.archlinux.org/index.php/PostgreSQL#Change_default_encoding_of_new_databases_to_UTF-8_.28optional.29)

### Install Ruby 1.9.2 through Ruby Version Manager

Install RVM:

    sudo apt-get install curl

    curl -L https://get.rvm.io | bash -s stable

    source /home/<user>/.rvm/scripts/rvm

Install RVM requirements:

    rvm requirements

Install Ruby 1.9.2 through RVM:

    rvm install 1.9.2

(Get some coffee...)

If you get a PATH warning now or later run (as suggested by rvm):

    rvm use ruby-1.9.2-p320@cartodb

### Install Redis and Varnish + python dependencies

    sudo apt-get install nodejs npm redis-server

    sudo apt-get install python-setuptools
    sudo apt-get install python-dev
    sudo apt-get install python-gdal

    sudo easy_install pip

    cd ~/cartodb20/

(Type "y" if you get a warning from RVM about .rvmrc)

    sudo pip install -r python_requirements.txt

    sudo pip install -e git+https://github.com/RealGeeks/python-varnish.git@0971d6024fbb2614350853a5e0f8736ba3fb1f0d#egg=python-varnish

Now you'll get:

    Obtaining python-varnish from git+https://github.com/RealGeeks/python-varnish.git@0971d6024fbb2614350853a5e0f8736ba3fb1f0d#egg=python-varnish
      git clone in ./src/python-varnish exists with URL git://github.com/CartoDB/python-varnish.git
      The plan is to install the git repository https://github.com/RealGeeks/python-varnish.git
    What to do?  (s)witch, (i)gnore, (w)ipe, (b)ackup s

Choose "switch" and let's hope it works.

### Install Mapnik

    sudo apt-get install libmapnik-dev python-mapnik mapnik-utils

### Install CartoDB SQL API

    cd ~

    git clone git://github.com/CartoDB/CartoDB-SQL-API.git
    cd CartoDB-SQL-API
    git checkout master
    npm install

Create config files:

    cd config/environments/
    cp development.js.example development.js

### Install tile server

    cd ~

    git clone git://github.com/CartoDB/Windshaft-cartodb.git
    cd Windshaft-cartodb
    git checkout master
    npm install

Config files:

    cd config/environments/
    cp development.js.example development.js

### Install Ruby gems and configure the Rails app

    export SUBDOMAIN=development

    cd ~/cartodb20

Redis must be running before starting the Node applications or Rails, and also before running the create_dev_user script:

    redis-server &

Install dependency for nokogiri:

    sudo apt-get install libxslt-dev

Install gems for the Rails app:

    rvm use 1.9.2@cartodb --create && bundle install


Set postgres password:

    sudo -u postgres psql
    \password
    (Set password)
    \q

Create/edit config files:

    cp config/app_config.yml.sample config/app_config.yml

For database set postgres password in the config file:

    cp config/database.yml.sample config/database.yml
    nano config/database.yml

Create the development user:

    sh script/create_dev_user ${SUBDOMAIN}

(Enter passwords and email)

To be able to use subdomain as user (also see below):

    echo "127.0.0.1 ${SUBDOMAIN}.localhost.lan" | sudo tee -a /etc/hosts


To be able to login, the username has to be the same as the subdomain name, which has been defined above in ${SUBDOMAIN} = development.

To achieve this you have to setup /etc/hosts in such a way that you can reach cartodb through a development.* subdomain:

What worked for me:

Add to /etc/hosts of the machine your calling carto from:

    192.168.56.10   development.localhost.lan

I also changed this in cartodb20/config/app_config.yml, but I don't know if it's really necessary...:

    developers_host:    'http://development.localhost.lan:3000'

### More configuring to get things to work

In Windshaft config/environments/development.js change:

	host: ''  //so the tiler listens to all IP addresses, not just localhost

	mapnik_version: '2.1.1' //to fool it into believing it has this version, needed because CartoCSS is based on this version of Mapnik

In SQL API config/environments/development.js change:

	module.exports.node_host    = '';  //idem

In cartodb20/config/app_config.yml:

    private:
      protocol:      'http'  // want met https werkt het niet

In /etc/postgresql/9.1/main/pg_hba.conf, set auth method to "trust":

	host     all             all             127.0.0.1/32            trust
	local    all             all                                     trust

to prevent error "password authentication failed for user publicuser" (source: https://github.com/CartoDB/Windshaft-cartodb/issues/61).

Change domain names!

A.o here: Windshaft/config/environments/development.js:

    ,sqlapi: {
        protocol: 'http',
        host: 'qmaps.nl',

### PGBouncer

PGBouncer has to be installed otherwise only the first import will work, see https://github.com/CartoDB/cartodb/issues/51

    sudo apt-get install pgbouncer

In /etc/pgbouncer/pgbouncer.ini:

    [databases]
    * = host=127.0.0.1 port=5432

    auth_type = trust

In /etc/pgbouncer/userlist.txt:

    "postgres" "passwd"
    "development_cartodb_user_1" "passwd"
    "publicuser"
    "tileuser"

In /etc/default/pgbouncer set

    START=1

Change port to 6432 in cartodb20/SQL API/Windshaft configuration files!

    sudo service pgbouncer restart

### Make shp2pgsql accessible through the path

To make shp2pgsql available on the path:

	sudo ln -s /usr/local/src/postgis-2.0.2/loader/shp2pgsql /usr/bin/shp2pgsql

### Upgrade database schema if needed

Upgrade to 2.1.2:

	bundle exec rake cartodb:db:create_importer_schema

### Run!

Start all services using foreman:

    bundle exec foreman start -p $PORT

## Production deployment

### Rails

Install Apache:

	sudo apt-get install apache2

Install Passenger, see http://www.modrails.com/documentation/Users%20guide%20Apache.html

	gem install passenger

Make phusion accesible to webserver:

	passenger-config --root

	chmod o+x /home/phusion/.rvm/gems/ruby-1.9.3-p362/gems/passenger-x.x.x
	chmod o+x /home/phusion/.rvm/gems/ruby-1.9.3-p362/gems
	chmod o+x /home/phusion/.rvm/gems/ruby-1.9.3-p362
	chmod o+x /home/phusion/.rvm/gems
	chmod o+x /home/phusion/.rvm
	chmod o+x /home/phusion

(Paths will be different.)

Install dependencies for Passenger:

	sudo apt-get install apache2-threaded-dev libapr1-dev libaprutil1-dev

Install and configure the Apache module:

	passenger-install-apache2-module

Create Apache config files for Passenger (see http://www.modrails.com/documentation/Users%20guide%20Apache.html#working_with_apache_conf).

Create /etc/apache2/mods-available/passenger.load containing:

	LoadModule passenger_module /home/quser/.rvm/gems/ruby-1.9.2-p320@cartodb/gems/passenger-4.0.10/buildout/apache2/mod_passenger.so

Create /etc/apache2/mods-available/passenger.conf containing:

	PassengerRoot /home/quser/.rvm/gems/ruby-1.9.2-p320@cartodb/gems/passenger-4.0.10
	PassengerDefaultRuby /home/quser/.rvm/wrappers/ruby-1.9.2-p320@cartodb/ruby

Enable the module!

	sudo a2enmod passenger

Suppose you have a Rails application in /somewhere. Add a virtual host to your
Apache configuration file and set its DocumentRoot to /somewhere/public:

Add to /etc/apache2/sites-available/default:

   <VirtualHost *:80>
      ServerName www.yourhost.com
      # !!! Be sure to point DocumentRoot to 'public'!
      DocumentRoot /somewhere/public    
      <Directory /somewhere/public>
         # This relaxes Apache security settings.
         AllowOverride all
         # MultiViews must be turned off.
         Options -MultiViews
      </Directory>
   </VirtualHost>

Restart Apache:

   sudo service apache2 restart

## Node.js

See https://www.exratione.com/2013/02/nodejs-and-forever-as-a-service-simple-upstart-and-init-scripts-for-ubuntu/

Globally install the Node module "forever":

    sudo npm -g install forever

Create init script

    sudo nano /etc/init.d/cartodb-windshaft

with contents:

	#!/bin/bash
	#
	# An example init script for running a Node.js process as a service
	# using Forever as the process monitor. For more configuration options
	# associated with Forever, see: https://github.com/nodejitsu/forever
	#
	# You will need to set the environment variables noted below to conform to
	# your use case, and change the init info comment block.
	#
	# This was written for Debian distributions such as Ubuntu, but should still
	# work on RedHat, Fedora, or other RPM-based distributions, since none
	# of the built-in service functions are used. If you do adapt it to a RPM-based
	# system, you'll need to replace the init info comment block with a chkconfig
	# comment block.
	#
	### BEGIN INIT INFO
	# Provides:             my-application
	# Required-Start:       $syslog $remote_fs
	# Required-Stop:        $syslog $remote_fs
	# Should-Start:         $local_fs
	# Should-Stop:          $local_fs
	# Default-Start:        2 3 4 5
	# Default-Stop:         0 1 6
	# Short-Description:    My Application
	# Description:          My Application
	### END INIT INFO
	#
	# Based on:
	# https://gist.github.com/3748766
	# https://github.com/hectorcorrea/hectorcorrea.com/blob/master/etc/forever-initd-hectorcorrea.sh
	# https://www.exratione.com/2011/07/running-a-nodejs-server-as-a-service-using-forever/
	 
	# Source function library. Note that this isn't used here, but remains to be
	# uncommented by those who want to edit this script to add more functionality.
	# Note that this is Ubuntu-specific. The scripts and script location are different on
	# RPM-based distributions.
	# . /lib/lsb/init-functions
	 
	# The example environment variables below assume that Node.js is 
	# installed into /home/node/local/node by building from source as outlined 
	# here:
	# https://www.exratione.com/2011/07/running-a-nodejs-server-as-a-service-using-forever/
	#
	# It should be easy enough to adapt to the paths to be appropriate to a 
	# package installation, but note that the packages available for Ubuntu in
	# the default repositories are far behind the times. Most users will be 
	# building from source to get a more recent Node.js version.
	#
	# An application name to display in echo text.
	# NAME="My Application"
	# The full path to the directory containing the node and forever binaries.
	# NODE_BIN_DIR=/home/node/local/node/bin
	# Set the NODE_PATH to the Node.js main node_modules directory.
	# NODE_PATH=/home/node/local/node/lib/node_modules
	# The directory containing the application start Javascript file.
	# APPLICATION_DIRECTORY=/home/node/my-application
	# The application start Javascript filename.
	# APPLICATION_START=start-my-application.js
	# Process ID file path.
	# PIDFILE=/var/run/my-application.pid
	# Log file path.
	# LOGFILE=/var/log/my-application.log
	#
	NAME=CartoDB Windshaft
	NODE_BIN_DIR=/usr/bin
	NODE_PATH=/home/quser/Windshaft-cartodb/node_modules
	APPLICATION_DIRECTORY=/home/quser/Windshaft-cartodb
	APPLICATION_START=app.js
	PIDFILE=/var/run/cartodb-windshaft.pid
	LOGFILE=/var/log/cartodb-windshaft.log
	 
	# Add node to the path for situations in which the environment is passed.
	PATH=$NODE_BIN_DIR:$PATH
	# Export all environment variables that must be visible for the Node.js
	# application process forked by Forever. It will not see any of the other
	# variables defined in this script.
	export NODE_PATH=$NODE_PATH
	 
	start() {
	    echo "Starting $NAME"
	    # We're calling forever directly without using start-stop-daemon for the
	    # sake of simplicity when it comes to environment, and because this way
	    # the script will work whether it is executed directly or via the service
	    # utility.
	    #
	    # The minUptime and spinSleepTime settings stop Forever from thrashing if
	    # the application fails immediately on launch. This is generally necessary to
	    # avoid loading development servers to the point of failure every time 
	    # someone makes an error in application initialization code, or bringing down
	    # production servers the same way if a database or other critical service
	    # suddenly becomes inaccessible.
	    #
	    # The pidfile contains the child process pid, not the forever process pid.
	    # We're only using it as a marker for whether or not the process is
	    # running.
	    forever --pidFile $PIDFILE --sourceDir $APPLICATION_DIRECTORY \
	        -a -l $LOGFILE --minUptime 5000 --spinSleepTime 2000 \
	        start $APPLICATION_START &
	    RETVAL=$?
	}
	 
	stop() {
	    if [ -f $PIDFILE ]; then
	        echo "Shutting down $NAME"
	        # Tell Forever to stop the process. Note that doing it this way means
	        # that each application that runs as a service must have a different
	        # start file name, regardless of which directory it is in.
	        forever stop $APPLICATION_START
	        # Get rid of the pidfile, since Forever won't do that.
	        rm -f $PIDFILE
	        RETVAL=$?
	    else
	        echo "$NAME is not running."
	        RETVAL=0
	    fi
	}
	 
	restart() {
	    echo "Restarting $NAME"
	    stop
	    start
	}
	 
	status() {
	    echo "Status for $NAME:"
	    # This is taking the lazy way out on status, as it will return a list of
	    # all running Forever processes. You get to figure out what you want to
	    # know from that information.
	    #
	    # On Ubuntu, this isn't even necessary. To find out whether the service is
	    # running, use "service my-application status" which bypasses this script
	    # entirely provided you used the service utility to start the process.
	    forever list
	    RETVAL=$?
	}
	 
	case "$1" in
	    start)
	        start
	        ;;
	    stop)
	        stop
	        ;;
	    status)
	        status
	        ;;
	    restart)
	        restart
	        ;;
	    *)
	        echo "Usage: {start|stop|status|restart}"
	        exit 1
	        ;;
	esac
	exit $RETVAL

Make executable:

    chmod a+x /etc/init.d/cartodb-windshaft

Update the runlevel configurations:

	sudo update-rc.d cartodb-windshaft defaults

Start the service!

	sudo service cartodb-windshaft start

Idem for the SQL API!

## Redis

Follow the steps under "Installing Redis more properly" at http://redis.io/topics/quickstart

	sudo mkdir /etc/redis
	sudo mkdir /var/redis
	sudo mkdir /var/redis/6379

Create /etc/init.d/redis_6379 with contents:

	#!/bin/sh
	#
	# Simple Redis init.d script conceived to work on Linux systems
	# as it does use of the /proc filesystem.
	 
	REDISPORT=6379
	EXEC=/usr/bin/redis-server
	CLIEXEC=/usr/bin/redis-cli
	 
	PIDFILE=/var/run/redis_${REDISPORT}.pid
	CONF="/etc/redis/${REDISPORT}.conf"
	 
	case "$1" in
	    start)
	        if [ -f $PIDFILE ]
	        then
	                echo "$PIDFILE exists, process is already running or crashed"
	        else
	                echo "Starting Redis server..."
	                $EXEC $CONF
	        fi
	        ;;
	    stop)
	        if [ ! -f $PIDFILE ]
	        then
	                echo "$PIDFILE does not exist, process is not running"
	        else
	                PID=$(cat $PIDFILE)
	                echo "Stopping ..."
	                $CLIEXEC -p $REDISPORT shutdown
	                while [ -x /proc/${PID} ]
	                do
	                    echo "Waiting for Redis to shutdown ..."
	                    sleep 1
	                done
	                echo "Redis stopped"
	        fi
	        ;;
	    *)
	        echo "Please use start or stop as first argument"
	        ;;
	esac

Create /etc/redis/6379.conf from default config file and change the following:

 * Set daemonize to yes (by default it is set to no).
 * Set the pidfile to /var/run/redis_6379.pid (modify the port if needed).
 * Change the port accordingly. In our example it is not needed as the default port is already 6379.
 * Set your preferred loglevel.
 * Set the logfile to /var/log/redis_6379.log
 * Set the dir to /var/redis/6379 (very important step!)

Make init script executable:

	sudo chmod a+x /etc/init.d/redis_6379

Start the service!

	sudo service redis_6379 start

## Setup SSL

Create /etc/apache2/sites-available/default-ssl with something like:

	<VirtualHost *:443>
	    ServerName carto.qmaps.nl
	    ServerAlias carto.qmaps.nl
	    # !!! Be sure to point DocumentRoot to 'public'!
	    DocumentRoot /home/quser/cartodb20/public
	    RailsEnv production
	    PassengerSpawnMethod direct

	    #TODO later: SSL options

	    <Directory /home/quser/cartodb20/public>
	        # This relaxes Apache security settings.
	        AllowOverride all
	        # MultiViews must be turned off.
	        Options -MultiViews
	    </Directory>
	</VirtualHost>

Enable SSL module:

    sudo a2enmod ssl

Enable SSL site:

    sudo a2ensite default-ssl

In /etc/apache2/ports.conf add NameVirtualHost 443:

    <IfModule mod_ssl.c>
        NameVirtualHost *:443
        Listen 443
    </IfModule>

Setup SSL certificate.... More...?

TODO

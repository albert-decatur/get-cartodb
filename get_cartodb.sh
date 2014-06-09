#!/bin/bash

# stand up CartoDB
# for ubuntu 12.04
# user args: 1) postgres password

pass=$1

if [[ -z $pass ]]; then
	echo -e "You must provide a password for PostgreSQL user postgres!\n"	
	exit 1;
fi

get_prereqs() {
	cd ~
	sudo apt-get update
	sudo apt-get -y install git-core
	git clone --recursive https://github.com/CartoDB/cartodb20.git
	sudo add-apt-repository -y ppa:cartodb/gis
	sudo add-apt-repository -y ppa:cartodb/mapnik
	sudo add-apt-repository -y ppa:mapnik/boost
	sudo add-apt-repository -y ppa:chris-lea/node.js-legacy
	sudo add-apt-repository -y ppa:cartodb/redis
	sudo add-apt-repository -y ppa:cartodb/postgresql
	sudo apt-get update
	sudo apt-get -y install unp
	sudo apt-get -y install zip
}

get_geos() {
	# compile GEOS 3.3.8 if the src dir doesn't exist
	if [[ ! -d /usr/local/src/geos-3.3.8 ]]; then
		cd /usr/local/src
		sudo wget http://download.osgeo.org/geos/geos-3.3.8.tar.bz2
		sudo tar xvfj geos-3.3.8.tar.bz2
		cd geos-3.3.8
		sudo ./configure
		sudo make
		sudo make install
		cd ~
	fi
}

get_postgres() {
	sudo apt-get install -y gdal-bin libgdal1-dev
	sudo apt-get install -y libjson0 python-simplejson libjson0-dev
	sudo apt-get install -y proj-bin proj-data libproj-dev
	sudo apt-get install -y postgresql-9.1 postgresql-client-9.1 postgresql-contrib-9.1 postgresql-server-dev-9.1
	sudo apt-get install -y postgresql-plpython-9.1
}

get_postgis() {
	# compile postgis if the src dir doesn't exist
	if [[ ! -d /usr/local/src/postgis-2.0.2 ]]; then
		cd /usr/local/src
		sudo wget http://download.osgeo.org/postgis/source/postgis-2.0.2.tar.gz
		sudo tar xzf postgis-2.0.2.tar.gz
		cd postgis-2.0.2
		sudo ./configure --with-raster --with-topology
		sudo make
		sudo make install
	fi
}

config_postgis() {
	if [[ ! -a /usr/local/src/postgis-2.0.2/es.sh ]]; then
		# make db template_postgis using script es.sh
		export LANG=en_US.UTF-8
		sudo cp /vagrant/es.sh /usr/local/src/postgis-2.0.2/es.sh
		# hmmm - insecure
		sudo chmod 777 /usr/local/src/postgis-2.0.2/es.sh
		sudo su - postgres -c "/usr/local/src/postgis-2.0.2/es.sh"
	fi
}

get_prereqs2() {
	sudo apt-get update
	#sudo apt-get -y install ruby1.9.1
	#sudo apt-get -y install ruby1.9.3
	sudo apt-get -y install nodejs=0.8.26-1chl1~precise1
	sudo apt-get -y install npm=1.3.0-1chl1~precise1
	sudo apt-get -y install redis-server
	sudo apt-get -y install python-setuptools
}

get_prereqs3() {
	cd ~/cartodb20/
	sudo easy_install pip
	# pip fails to build gdal - is this ok?
	sudo pip install -r python_requirements.txt
	sudo apt-get -y install varnish
	sudo apt-get -y install libmapnik-dev python-mapnik2 mapnik-utils
	cd ~
}

get_cartodb-sql-api(){
	# cartodb-sql-api
	# got this error: node-pre-gyp ERR! Source compile required: 403 status code downloading tarball
	git clone https://github.com/CartoDB/CartoDB-SQL-API.git
	cd CartoDB-SQL-API
	git checkout master
	npm install
	cd config/environments/
	cp development.js.example development.js
	cd ../..
	node app.js development &
	cd ~
}

get_windshaft-cartodb() {
	git clone git://github.com/CartoDB/Windshaft-cartodb.git
	cd Windshaft-cartodb/
	git checkout master
	npm install
	cd config/environments/
	cp development.js.example development.js
	cd ../..
	mkdir logs/
	# does this succeed?
	node app.js development &
}

get_ruby() {
	cd ~
	curl -L https://get.rvm.io | bash
	source /home/vagrant/.rvm/scripts/rvm
	rvm install 1.9.3
}


bundle_cartodb() {
	cd ~/cartodb20
	redis-server &
	rvm use 1.9.3@cartodb --create && bundle install
	# not sure what you get and don't get from rvmsudo
	# need to run as root?
	#rvmsudo bundle install
	cd ~
}

config_cartodb() {
	cd ~/cartodb20
	cp config/app_config.yml.sample config/app_config.yml
	cp config/database.yml.sample config/database.yml
	export SUBDOMAIN=development
	echo "127.0.0.1 ${SUBDOMAIN}.localhost.lan" | sudo tee -a /etc/hosts
	cd ~
}

config_further() {
	cd ~/cartodb20
	# make a copy of the original pg_hba.conf
	sudo cp /etc/postgresql/9.1/main/pg_hba.conf /etc/postgresql/9.1/main/.pg_hba.conf.bak
	# replace md5 and peer with trust in pg_hba.conf. security??
	sudo apt-get install moreutils # to get sponge
	sudo cat /etc/postgresql/9.1/main/pg_hba.conf | sed 's:peer$\|md5$:trust:g' | sudo sponge /etc/postgresql/9.1/main/pg_hba.conf
	# change postgres user password
	a="'" # need to make apostraphe a var to expand password var
	sudo -u postgres psql -U postgres -d postgres -c "alter user postgres with password ${a}${pass}${a};"
	# copy original database config to backup file
	cp config/database.yml config/.database.yml.bak
	# set postgres passwords in config/database.yml
	cat config/database.yml | sed "s:\(\spassword\:\):\1 $pass:g" | sponge config/database.yml
	# give permission over pg_hba.conf to postgres user
	sudo chown postgres:postgres /etc/postgresql/9.1/main/pg_hba.conf
	# restart postgres
	sudo service postgresql restart
}

get_prereqs
get_geos
get_postgres
get_postgis
config_postgis
get_prereqs2
get_prereqs3
get_cartodb-sql-api
get_windshaft-cartodb
get_ruby
config_cartodb
config_further
bundle_cartodb


## run create dev user script
#sh script/create_dev_user ${SUBDOMAIN}

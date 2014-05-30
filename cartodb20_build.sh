###################################
## CartoDB 2.0 Install [Working] ##
## Tested on Ubuntu 12.04        ##
###################################

# Basic upgrades
sudo aptitude update
sudo aptitude safe-upgrade -y

# Install miscellaneous dependencies packages
sudo aptitude install -y git-core python-software-properties openmpi-bin libopenmpi-dev build-essential libxslt-dev zlib1g-dev ruby gems unzip

# Install RVM
bash -s stable < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer )
source ~/.bash_profile

# Install ruby and its dependencies
rvm pkg install openssl
# rvm pkg install zlib
rvm install 1.9.2 --with-openssl-dir=$rvm_path/usr # Not sure this needs to be specified
## ENTER q
rvm use 1.9.2
rvm use 1.9.2 --default
sudo aptitude install -y build-essential openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config

# Install CartoDB repo and unp
git clone --recursive https://github.com/CartoDB/cartodb20.git
cd cartodb20
git checkout master
git submodule update
git submodule foreach git checkout master
sudo aptitude install -y unp

# Install GDAL, GEOS, PROJ, JSON-C, and PostGIS
echo 'yes' | sudo add-apt-repository ppa:ubuntugis/ubuntugis-unstable
sudo apt-get update
sudo apt-get install -y libgdal-dev libgeos-dev libproj-dev gdal-bin postgis postgresql-plpython-9.1 libjson0 libjson0-dev python-gdal

# Install Redis
sudo aptitude install -y redis-server

# Install python dependencies
sudo aptitude install -y python-setuptools python-dev
sudo easy_install pip
cd cartodb20
## ENTER 'y'  -- maybe hit 'n'?
sudo pip install -r python_requirements.txt
sudo pip install -e git+https://github.com/RealGeeks/python-varnish.git@0971d6024fbb2614350853a5e0f8736ba3fb1f0d#egg=python-varnish
## ENTER 's'
cd ~

# Install Mapnik
echo 'yes' | sudo add-apt-repository ppa:mapnik/v2.0.2
sudo apt-get update
sudo aptitude install -y libmapnik mapnik-utils python-mapnik libmapnik-dev

# Install Node (For CDB 2.0, need version higher than what apt has, v0.6.12, so we will install from source.)
git clone https://github.com/joyent/node.git
cd ./node
git checkout v0.8.25-release ## 0.6.19 version works (I think?) with both CartoDB-SQL-API and Windshaft but try 0.4.12
./configure
make
sudo make install
cd ..

# Install npm
curl https://npmjs.org/install.sh | sudo sh

## Install CartoDB SQL API (need nodejs 0.8.x; works on 0.8.25)
git clone git://github.com/Vizzuality/CartoDB-SQL-API.git
cd CartoDB-SQL-API
sudo npm install
cd ..


## Mapnik requires a ton of RAM to compile, so setup a swapdisk if needed.
cd /
sudo dd if=/dev/zero of=swapfile bs=1M count=3000
sudo mkswap swapfile
sudo swapon swapfile
sudo pico /etc/fstab ## Add:  /swapfile none swap sw 0 0
cd ~

## To try: install mapnik latest PPA
## Install nvm and install 0.6.19 from it (For CDB 2.0 install, seems to work fine with node v0.8.25)
git clone git://github.com/Vizzuality/Windshaft-cartodb.git
cd Windshaft-cartodb
sudo npm install
cd ../

cd cartodb20
bundle install --binstubs

## Set the right stuff here!
mv config/app_config.yml.sample config/app_config.yml
pico config/app_config.yml

mv config/database.yml.sample config/database.yml
pico config/database.yml


# Install varnish
sudo curl http://repo.varnish-cache.org/debian/GPG-key.txt | sudo apt-key add -
sudo pico /etc/apt/sources.list
# ADD: deb http://repo.varnish-cache.org/ubuntu/ lucid varnish-3.0
sudo aptitude update
sudo aptitude install varnish


## This inits the postgres–CartoDB connection & DBs
sed -i 's,some_secret,3b7de655b4a0064e0e08a7dc4a3eb156,g' ~/cartodb20/config/app_config.yml
sudo rm /etc/postgresql/9.1/main/pg_hba.conf
sudo touch /etc/postgresql/9.1/main/pg_hba.conf
sudo sh -c "echo 'local   all             postgres                                trust' >> /etc/postgresql/9.1/main/pg_hba.conf "
sudo sh -c "echo 'local   all             all                                     trust' >> /etc/postgresql/9.1/main/pg_hba.conf "
sudo sh -c "echo 'host    all             all             127.0.0.1/32            trust' >> /etc/postgresql/9.1/main/pg_hba.conf "
sudo sh -c "echo 'host    all             all             ::1/128                 trust' >> /etc/postgresql/9.1/main/pg_hba.conf "
sudo chown postgres:postgres /etc/postgresql/9.1/main/pg_hba.conf
sudo /etc/init.d/postgresql restart


# Setup PostgreSQL with needed template
sudo pg_dropcluster --stop 9.1 main
sudo pg_createcluster --start -e UTF-8 9.1 main


sudo su - postgres
cd ~

pico template # Add the following:
#####
#!/bin/bash
POSTGIS_SQL_PATH=/usr/share/postgresql/9.1/contrib/postgis-2.0
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
#####
chmod +x template
./template


export SUBDOMAIN=yoursubdomain
echo "127.0.0.1 ${SUBDOMAIN}.localhost.lan" | sudo tee -a /etc/hosts
sh script/create_dev_user ${SUBDOMAIN}
exit


# touch ~/cartodb/config/redis.conf # Needed for CDB 2.0?
rails server -p 3000 ## Don't need this if starting with foreman as below



# EXPERIMENTAL
## make sure to rvmsudo any rails command that needs sudoing
## Also, be sure to make sure POSTGRES and REDIS aren't launching on boot if using foreman.
## (Could also change PROCFILE to restart these services rather than just starting them)
## also make sure postgres default port is 5432 and not 5433.

rvmsudo bundle exec foreman start -p 80

## OR add it add a startup item (can control via start cartodb, stop cartodb, restart cartodb)
rvmsudo foreman export upstart /etc/init --start-on-boot --user eric --port 80 --app cartodb

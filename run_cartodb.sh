#!/bin/bash

cd ~
node CartoDB-SQL-API/app.js development &
node Windshaft-cartodb/app.js development &
redis-server &
cd ~/cartodb20/
rvm use 1.9.2@cartodb --create && bundle install
QUEUE=* bundle exec rake resque:work &
bundle exec rails s -p 3000 &

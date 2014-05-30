#!/usr/bin/env bash                                                                                                            
POSTGIS_SQL_PATH=$(pg_config --sharedir)/contrib/postgis-2.0                                                                   
createdb -E UTF8 --locale=en_US.utf8 -T template0 template_postgis                                                             
createlang -d template_postgis plpgsql                                                                                         
psql -d postgres -c \                                                                                                          
"UPDATE pg_database SET datistemplate='true' WHERE datname='template_postgis'"                                                 
psql -d template_postgis -f /usr/local/src/postgis-2.0.2/postgis/postgis.sql                                                                                
psql -d template_postgis -f /usr/local/src/postgis-2.0.2/spatial_ref_sys.sql                                                                                
psql -d template_postgis -f /usr/local/src/postgis-2.0.2/postgis/legacy.sql                                                                                 
psql -d template_postgis -f /usr/local/src/postgis-2.0.2/taster/rt_pg/rtpostgis.sql                                                                         
psql -d template_postgis -f /usr/local/src/postgis-2.0.2/topology/topology.sql                                                                              
psql -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;"                                                         
psql -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"

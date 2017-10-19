#!/usr/bin/env bash

case $(uname) in
  "Darwin") SED_REGEXP_EXTENDED='-E' ;;
  *) SED_REGEXP_EXTENDED='-r' ;;
esac

# get the port offset from config variable
function get_port_offset {
  local offset=0
 
  if [ -n "${CL_PORT_OFFSET}" ]; then
    offset=${CL_PORT_OFFSET}
  fi

  echo ${offset}
}

function check_port {
  local port=$1
  local offset=$(get_port_offset)
  local tocheck=$((port+offset))
  if (: < /dev/tcp/127.0.0.1/${tocheck}) 2>/dev/null; then
    echo "Error: port ${tocheck} is already taken (orig port ${port} with offset ${offset})"
    exit 1
  fi
}

function check_ports {
  check_port 2181 # zookeeper

  check_port 9092 # kafka broker
  
  # hadoop
  check_port 50010 # dfs.datanode.address
  check_port 50020 # dfs.datanode.ipc.address
  check_port 50075 # dfs.datanode.http.address
  check_port 50475 # dfs.datanode.https.address
  
  check_port 8020  # namenode data
  check_port 9000  # namenode data
  check_port 50070 # namenode http
  check_port 50470 # namenode https
  
  check_port 50090 # secondary name node
  
  check_port 8088  # yarn job tracker
  check_port 8030  # yarn
  check_port 8031  # yarn
  check_port 8032  # yarn
  check_port 8033  # yarn
  
  check_port 8090  # yarn
  check_port 8040  # yarn
  check_port 8042  # yarn
  
  # accumulo
  check_port 50095 # accumulo monitor
  check_port 4560  # accumulo monitor
  check_port 9997  # accumulo tserver
  check_port 50091 # accumulo gc
  check_port 9999  # accumulo master
  check_port 12234 # accumulo tracer

  # hbase
  check_port 16000 # hbase master
  check_port 16010 # hbase master info
  check_port 16020 # hbase regionserver
  check_port 16030 # hbase regionserver info
  check_port 16040 # hbase rest
  check_port 16100 # hbase multicast  

  # spark
  check_port 4040 # Spark job monitor

  # Zeppelin
  check_port 5771 # Zeppelin embedded web server

  echo "Known ports are OK (using offset $(get_port_offset))"
}

function configure_port_offset {
  local offset=$(get_port_offset)

  local KEY="CL_port_default"
  local KEY_CHANGED="CL_offset_port"

  # zookeeper (zoo.cfg)
  # do this one by hand, it's fairly straightforward
  zkPort=$((2181+offset))
  sed -i~orig "s/clientPort=.*/clientPort=$zkPort/" $ZOOKEEPER_HOME/conf/zoo.cfg

  # kafka (server.properties)
  kafkaPort=$((9092+offset))
  sed -i~orig "s/\/\/$CL_HOSTNAME:[0-9].*/\/\/$CL_HOSTNAME:$kafkaPort/" $KAFKA_HOME/config/server.properties
  sed -i~orig "s/zookeeper.connect=$CL_HOSTNAME:[0-9].*/zookeeper.connect=$CL_HOSTNAME:$zkPort/" $KAFKA_HOME/config/server.properties

  # Zeppelin
  if [[ "$zeppelin_enabled" -eq 1 ]]; then
    zeppelinPort=$((5771+offset))
    sed -i~orig "s/ZEPPELIN_PORT=[0-9]\{1,5\}\(.*\)/ZEPPELIN_PORT=$zeppelinPort\1/g" "$ZEPPELIN_HOME/conf/zeppelin-env.sh"
  fi

  # hadoop and accumulo xml files
  # The idea with this block is that the xml files have comments which tag lines which need
  # a port replacement, and the comments provide the default values. So to change ports,
  # we replace all the instance of the default value, on the line with the comment, with
  # the desired (offset) port.

  # TODO fix this to check for hbase/accumulo enabled
  for FILE in $ACCUMULO_HOME/conf/accumulo-site.xml \
              $HBASE_HOME/conf/hbase-site.xml \
              $HADOOP_CONF_DIR/core-site.xml \
              $HADOOP_CONF_DIR/hdfs-site.xml \
              $HADOOP_CONF_DIR/mapred-site.xml \
              $HADOOP_CONF_DIR/yarn-site.xml; do
    while [ -n "$(grep $KEY $FILE)" ]; do # while lines need to be changed
        # pull the default port out of the comment
        basePort=$(grep -hoE "$KEY [0-9]+" $FILE | head -1 | grep -hoE [0-9]+)
        # calculate new port
        newPort=$(($basePort+$offset))
        # the assumption here is that all port values are right before the '</value>' tag
        # the following sed only makes the replacement on a single line, containing the matched comment
        sed -i~orig ${SED_REGEXP_EXTENDED} "/$KEY $basePort/ s#[0-9]+</value>#$newPort</value>#" $FILE
        # mark this line done
        sed -i~orig ${SED_REGEXP_EXTENDED} "s/$KEY $basePort/$KEY_CHANGED $basePort/" $FILE
    done
    # re-mark all comment lines, so we can change ports again later if we want
    sed -i~orig "s/$KEY_CHANGED/$KEY/g" $FILE
  done

  echo "Ports configured to use offset $offset"
}

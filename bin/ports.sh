#!/usr/bin/env bash

function check_port {
  local port=$1
  if (: < /dev/tcp/127.0.0.1/$port) 2>/dev/null; then
    echo "Error: port $port is already taken"
    exit 1
  fi
}

function port_offset {
  local offset=0

  if [ -n "$CLOUD_LOCAL_PORT_OFFSET" ]; then
    offset=$CLOUD_LOCAL_PORT_OFFSET
  fi

  echo $offset
}

function check_ports {
  local offset=$1

  check_port $((2181+$offset))  # zookeeper
  
  # hadoop
  check_port $((50010+$offset)) # dfs.datanode.address
  check_port $((50020+$offset)) # dfs.datanode.ipc.address
  check_port $((50075+$offset)) # dfs.datanode.http.address
  check_port $((50475+$offset)) # dfs.datanode.https.address
  
  check_port $((8020+$offset))  # namenode data
  check_port $((9000+$offset))  # namenode data
  check_port $((50070+$offset)) # namenode http
  check_port $((50470+$offset)) # namenode https
  
  check_port $((50090+$offset)) # secondary name node
  
  check_port $((8088+$offset))  # yarn job tracker
  check_port $((8030+$offset))  # yarn
  check_port $((8031+$offset))  # yarn
  check_port $((8032+$offset))  # yarn
  check_port $((8033+$offset))  # yarn
  check_port $((8090+$offset))  # yarn

  check_port $((8040+$offset))  # yarn
  check_port $((8042+$offset))  # yarn

  check_port $((13562+$offset)) # mapreduce.shuffle.port
  check_port $((10020+$offset)) # mapreduce.jobhistory.address
  check_port $((19888+$offset)) # mapreduce.jobhistory.webapp.address
  check_port $((50030+$offset)) # mapreduce.jobhistory.http.address
  check_port $((50050+$offset)) # mapreduce.tasktracker.http.address
  
  # accumulo
  check_port $((50095+$offset)) # accumulo monitor (client)
  check_port $((4560+$offset))  # accumulo monitor (log4j)
  check_port $((9997+$offset))  # accumulo tserver
  check_port $((50091+$offset)) # accumulo gc
  check_port $((9999+$offset))  # accumulo master
  check_port $((12234+$offset)) # accumulo tracer
  
  echo "Known ports are OK"
}

function set_ports {
  local offset=$1

  local KEY=CL_port_default
  local KEY_CHANGED=CL_offset_port

  # zookeeper (zoo.cfg)
  # do this one by hand, it's fairly straightforward
  zkPort=$((2181+$offset))
  sed -i "s/clientPort=.*/clientPort=$zkPort/" $ZOOKEEPER_HOME/conf/zoo.cfg

  # hadoop and accumulo xml files
  # The idea with this block is that the xml files have comments which tag lines which need
  # a port replacement, and the comments provide the default values. So to change ports,
  # we replace all the instance of the default value, on the line with the comment, with
  # the desired (offset) port.
  for FILE in $ACCUMULO_HOME/conf/accumulo-site.xml \
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
        sed -i -r "/$KEY $basePort/ s#[0-9]+</value>#$newPort</value>#" $FILE
        # mark this line done
        sed -i -r "s/$KEY $basePort/$KEY_CHANGED $basePort/" $FILE
    done
    # re-mark all comment lines, so we can change ports again later if we want
    sed -i "s/$KEY_CHANGED/$KEY/g" $FILE
  done

  echo "Ports updated with offset $offset"
}
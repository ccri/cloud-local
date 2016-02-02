#!/usr/bin/env bash

function check_port {
  local port=$1
  if (: < /dev/tcp/127.0.0.1/$port) 2>/dev/null; then
    echo "Error: port $port is already taken"
    exit 1
  fi
}

function check_ports {
  check_port 2181  # zookeeper
  
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

  check_port 46040 # nifi bootstrap   

  echo "Known ports are OK"
}


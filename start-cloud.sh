#!/usr/bin/env bash

source .env

# start zk
echo "Starting zoo..."
zkServer.sh start

# start hadoop
echo "Starting hadoop..."
hadoop-daemon.sh --config $HADOOP_CONF_DIR start namenode
hadoop-daemon.sh --config $HADOOP_CONF_DIR start secondarynamenode
hadoop-daemon.sh --config $HADOOP_CONF_DIR start datanode
yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager

# Wait for HDFS to exit safemode:
echo "Waiting for HDFS to exit safemode..."
hdfs dfsadmin -safemode wait

# starting accumulo
echo "starting accumulo..."
$ACCUMULO_HOME/bin/start-all.sh


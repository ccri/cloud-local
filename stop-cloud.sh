#!/usr/bin/env bash

source .env

echo "Stopping accumulo..."
$ACCUMULO_HOME/bin/stop-all.sh

echo "Stopping yarn and dfs..."
$HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop resourcemanager
$HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop nodemanager
$HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop namenode
$HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop secondarynamenode
$HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop datanode

echo "stopping zookeeper"
$ZOOKEEPER_HOME/bin/zkServer.sh stop

#!/usr/bin/env bash

# thanks accumulo for these resolutions snippets
# Start: Resolve Script Directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "${SOURCE}" ]; do # resolve $SOURCE until the file is no longer a symlink
   bin="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
   SOURCE="$(readlink "${SOURCE}")"
   [[ "${SOURCE}" != /* ]] && SOURCE="${bin}/${SOURCE}" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
bin="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
script=$( basename "${SOURCE}" )
# Stop: Resolve Script Directory

# Start: config
. "${bin}"/config.sh

if [[ -z "$JAVA_HOME" ]];then
  echo "must set JAVA_HOME..."
  exit 1
fi
# Stop: config

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


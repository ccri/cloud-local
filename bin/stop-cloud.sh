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

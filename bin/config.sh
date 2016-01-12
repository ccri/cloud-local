#!/usr/bin/env bash

# thanks accumulo for these resolutions snippets
if [ -z "${CLOUD_HOME}" ] ; then
  # Start: Resolve Script Directory
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
     bin="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
     SOURCE="$(readlink "$SOURCE")"
     [[ $SOURCE != /* ]] && SOURCE="$bin/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  bin="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  script=$( basename "$SOURCE" )
  # Stop: Resolve Script Directory

  CLOUD_HOME=$( cd -P ${bin}/.. && pwd )
  export CLOUD_HOME
fi

if [ ! -d "${CLOUD_HOME}" ]; then
  echo "CLOUD_HOME=${CLOUD_HOME} is not a valid directory. Please make sure it exists"
  exit 1
fi

export ZOOKEEPER_HOME=$CLOUD_HOME/zookeeper-3.4.6

export HADOOP_HOME=$CLOUD_HOME/hadoop-2.6.3
export HADOOP_PREFIX=$CLOUD_HOME/hadoop-2.6.3
export YARN_HOME=$CLOUD_HOME/hadoop-2.6.3
export HADOOP_CONF_DIR=$CLOUD_HOME/hadoop-2.6.3/etc/hadoop

export ACCUMULO_HOME=$CLOUD_HOME/accumulo-1.6.4

export PATH=$ZOOKEEPER_HOME/bin:$ACCUMULO_HOME/bin:$HADOOP_HOME/sbin:$HADOOP_HOME/bin:$PATH

if [[ -z "$JAVA_HOME" ]];then
  echo "must set JAVA_HOME..."
  exit 1
fi


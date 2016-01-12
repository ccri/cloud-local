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

function download_packages() {
  # get stuff
  echo "Downloading packages from internet..."
  mkdir $CLOUD_HOME/pkg # todo check to see if this exists
  mirror="http://mirrors.ibiblio.org"
  declare -a urls=("$mirror/apache/accumulo/1.6.4/accumulo-1.6.4-bin.tar.gz"
                   "$mirror/apache/hadoop/common/hadoop-2.6.3/hadoop-2.6.3.tar.gz"
                   "$mirror/apache/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz") 
  
  for x in "${urls[@]}"; do
      fname=$(basename "$x");
      echo "fetching ${x}";
      wget -O "$CLOUD_HOME/pkg/${fname}" "$x";
  done 
}

function unpackage {
  echo "Unpackaging software..."
  (cd -P "$CLOUD_HOME" && tar xvf $CLOUD_HOME/pkg/zookeeper-3.4.6.tar.gz)
  (cd -P "$CLOUD_HOME" && tar xvf $CLOUD_HOME/pkg/accumulo-1.6.4-bin.tar.gz)
  (cd -P "$CLOUD_HOME" && tar xvf $CLOUD_HOME/pkg/hadoop-2.6.3.tar.gz)
}

function configure {
  mkdir -p $CLOUD_HOME/tmp/staging
  cp -r $CLOUD_HOME/templates/* $CLOUD_HOME/tmp/staging/
  ## Substitute env vars
  sed -i "s#LOCAL_CLOUD_PREFIX#$CLOUD_HOME#" $CLOUD_HOME/tmp/staging/*/*
  
  echo "Deploying config..."
  cp $CLOUD_HOME/tmp/staging/hadoop/* $HADOOP_CONF_DIR/
  cp $CLOUD_HOME/tmp/staging/zookeeper/* $ZOOKEEPER_HOME/conf/
  
  rm $CLOUD_HOME/tmp/staging -rf
}

function start_first_time {
  # start zk
  echo "Starting zoo..."
  $ZOOKEEPER_HOME/bin/zkServer.sh start
  
  # format namenode
  echo "Formatting namenode..."
  $HADOOP_HOME/bin/hadoop namenode -format
  
  # start hadoop
  echo "Starting hadoop..."
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start namenode
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start secondarynamenode
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start datanode
  $HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
  $HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager
  
  # Wait for HDFS to exit safemode:
  echo "Waiting for HDFS to exit safemode..."
  $HADOOP_HOME/bin/hdfs dfsadmin -safemode wait
  
  # create user homedir
  echo "Creating hdfs path /user/$USER"
  $HADOOP_HOME/bin/hadoop fs -mkdir -p "/user/$USER"
  
  # create accumulo config
  cp $ACCUMULO_HOME/conf/examples/3GB/standalone/* $ACCUMULO_HOME/conf/
  
  # init accumulo
  echo "Initializing accumulo"
  $ACCUMULO_HOME/bin/accumulo init
  
  # starting accumulo
  echo "starting accumulo..."
  $ACCUMULO_HOME/bin/start-all.sh
}

function clear_sw {
  rm $CLOUD_HOME/accumulo-1.6.4 -rf
  rm $CLOUD_HOME/hadoop-2.6.3 -rf
  rm $CLOUD_HOME/zookeeper-3.4.6 -rf
  rm $CLOUD_HOME/tmp -rf
}

function clear_data {
  # TODO prompt
  rm $CLOUD_HOME/data/yarn/* -rf
  rm $CLOUD_HOME/data/zookeeper/* -rf
  rm $CLOUD_HOME/data/dfs/data/* -rf
  rm $CLOUD_HOME/data/dfs/name/* -rf
}

function show_help {
  echo "Provide 1 parameter: (init|reconfigure|clean|help)"
}

if [ "$#" -ne 1 ]; then
  show_help
  exit 1
fi

if [[ $1 == 'init' ]]; then
  download_packages && unpackage && configure && start_first_time
elif [[ $1 == 'reconfigure' ]]; then
  echo "reconfiguring..."
  #TODO ensure everything is stopped? prompt to make sure?
  clear_sw && clear_data && unpackage && configure && start_first_time
elif [[ $1 == 'clean' ]]; then
  echo "cleaning..."
  clear_sw && clear_data
  echo "cleaned!"
else
  show_help
fi




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

# import port checking
. "${bin}"/ports.sh

function download_packages() {
  # get stuff
  echo "Downloading packages from internet..."
  test -d ${CLOUD_HOME}/pkg || mkdir ${CLOUD_HOME}/pkg
  local mirror=${pkg_src_mirror}
  local maven=${pkg_src_maven}

  if [ -z "$CLOUD_LOCAL_PKGS" ]; then
    declare -a urls=("${maven}/org/apache/accumulo/accumulo/${pkg_accumulo_ver}/accumulo-${pkg_accumulo_ver}-bin.tar.gz"
                     "${mirror}/hadoop/common/hadoop-${pkg_hadoop_ver}/hadoop-${pkg_hadoop_ver}.tar.gz"
                     "${mirror}/zookeeper/zookeeper-${pkg_zookeeper_ver}/zookeeper-${pkg_zookeeper_ver}.tar.gz")

    for x in "${urls[@]}"; do
        fname=$(basename "$x")
        echo "fetching ${x}"
        wget -O "${CLOUD_HOME}/pkg/${fname}" "$x"
    done
  else
    declare -a urls=("${CLOUD_LOCAL_PKGS}/accumulo-${pkg_accumulo_ver}-bin.tar.gz"
                     "${CLOUD_LOCAL_PKGS}/hadoop-${pkg_hadoop_ver}.tar.gz"
                     "${CLOUD_LOCAL_PKGS}/zookeeper-${pkg_zookeeper_ver}.tar.gz")

    for x in "${urls[@]}"; do
        fname=$(basename "$x")
        echo "fetching ${x}"
        cp $x ${CLOUD_HOME}/pkg/${fname}
    done
  fi
}

function unpackage {
  echo "Unpackaging software..."
  local TARG=xf
  if [ -n "$CLOUD_LOCAL_VERBOSE" ]; then
    TARG=xvf
  fi
  (cd -P "${CLOUD_HOME}" && tar $TARG "${CLOUD_HOME}/pkg/zookeeper-${pkg_zookeeper_ver}.tar.gz")
  (cd -P "${CLOUD_HOME}" && tar $TARG "${CLOUD_HOME}/pkg/accumulo-${pkg_accumulo_ver}-bin.tar.gz")
  (cd -P "${CLOUD_HOME}" && tar $TARG "${CLOUD_HOME}/pkg/hadoop-${pkg_hadoop_ver}.tar.gz")
}

function configure {
  mkdir -p "${CLOUD_HOME}/tmp/staging"
  cp -r ${CLOUD_HOME}/templates/* ${CLOUD_HOME}/tmp/staging/
  ## Substitute env vars
  sed -i "s#LOCAL_CLOUD_PREFIX#${CLOUD_HOME}#" ${CLOUD_HOME}/tmp/staging/*/*
  
  echo "Deploying config..."
  test -d $HADOOP_CONF_DIR || mkdir $HADOOP_CONF_DIR
  test -d $ZOOKEEPER_HOME/conf || mkdir $ZOOKEEPER_HOME/conf
  test -d $ACCUMULO_HOME/conf || mkdir $ACCUMULO_HOME/conf
  cp ${CLOUD_HOME}/tmp/staging/hadoop/* $HADOOP_CONF_DIR/
  cp ${CLOUD_HOME}/tmp/staging/zookeeper/* $ZOOKEEPER_HOME/conf/

  # create accumulo config
  cp $ACCUMULO_HOME/conf/examples/3GB/standalone/* $ACCUMULO_HOME/conf/
  # make accumulo bind to all network interfaces (so you can see the monitor from other boxes)
  sed -i "s/\# export ACCUMULO_MONITOR_BIND_ALL=\"true\"/export ACCUMULO_MONITOR_BIND_ALL=\"true\"/" "${ACCUMULO_HOME}/conf/accumulo-env.sh"
  cp ${CLOUD_HOME}/tmp/staging/accumulo/* $ACCUMULO_HOME/conf/

  set_ports $(port_offset)

  rm ${CLOUD_HOME}/tmp/staging -rf
}

function start_first_time {
  # check ports
  check_ports $(port_offset)

  # start zk
  echo "Starting zoo..."
  $ZOOKEEPER_HOME/bin/zkServer.sh start
  
  # format namenode
  echo "Formatting namenode..."
  $HADOOP_HOME/bin/hadoop namenode -format
  
  # start hadoop
  echo "Starting hadoop..."
  export HADOOP_PID_DIR=$HADOOP_HOME/../tmp # make this unique to each cloud-local
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start namenode
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start secondarynamenode
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start datanode

  export YARN_PID_DIR=$HADOOP_HOME/../tmp
  $HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
  $HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager
  
  # Wait for HDFS to exit safemode:
  echo "Waiting for HDFS to exit safemode..."
  $HADOOP_HOME/bin/hdfs dfsadmin -safemode wait
  
  # create user homedir
  echo "Creating hdfs path /user/$USER"
  $HADOOP_HOME/bin/hadoop fs -mkdir -p "/user/$USER"

  # init accumulo
  echo "Initializing accumulo"
  $ACCUMULO_HOME/bin/accumulo init
  
  # starting accumulo
  echo "starting accumulo..."
  $ACCUMULO_HOME/bin/start-all.sh
}

function start_cloud {
  # Check ports
  check_ports $(port_offset)
  
  # start zk
  echo "Starting zoo..."
  zkServer.sh start
  
  # start hadoop
  echo "Starting hadoop..."
  export HADOOP_PID_DIR=$HADOOP_HOME/../tmp # make this unique to each cloud-local
  hadoop-daemon.sh --config $HADOOP_CONF_DIR start namenode
  hadoop-daemon.sh --config $HADOOP_CONF_DIR start secondarynamenode
  hadoop-daemon.sh --config $HADOOP_CONF_DIR start datanode

  export YARN_PID_DIR=$HADOOP_HOME/../tmp
  yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
  yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager
  
  # Wait for HDFS to exit safemode:
  echo "Waiting for HDFS to exit safemode..."
  hdfs dfsadmin -safemode wait
  
  # starting accumulo
  echo "starting accumulo..."
  $ACCUMULO_HOME/bin/start-all.sh
}

function stop_cloud {
  echo "Stopping accumulo..."
  $ACCUMULO_HOME/bin/stop-all.sh
  
  echo "Stopping yarn and dfs..."
  export YARN_PID_DIR=$HADOOP_HOME/../tmp
  $HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop resourcemanager
  $HADOOP_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR stop nodemanager
  export HADOOP_PID_DIR=$HADOOP_HOME/../tmp # make this unique to each cloud-local
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop namenode
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop secondarynamenode
  $HADOOP_HOME/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR stop datanode
  
  echo "stopping zookeeper"
  $ZOOKEEPER_HOME/bin/zkServer.sh stop
}

function clear_sw {
  rm "${CLOUD_HOME}/accumulo-${pkg_accumulo_ver}" -rf
  rm "${CLOUD_HOME}/hadoop-${pkg_hadoop_ver}" -rf
  rm "${CLOUD_HOME}/zookeeper-${pkg_zookeeper_ver}" -rf
  rm "${CLOUD_HOME}/tmp" -rf
}

function clear_data {
  # TODO prompt
  rm ${CLOUD_HOME}/data/yarn/* -rf
  rm ${CLOUD_HOME}/data/zookeeper/* -rf
  rm ${CLOUD_HOME}/data/dfs/data/* -rf
  rm ${CLOUD_HOME}/data/dfs/name/* -rf
}

function show_help {
  echo "Provide 1 command: (init|start|stop|reconfigure|clean|help)"
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
elif [[ $1 == 'start' ]]; then
  echo "Starting cloud..."
  start_cloud
  echo "Cloud Started"
elif [[ $1 == 'stop' ]]; then
  echo "Stopping Cloud..."
  stop_cloud
  echo "Cloud stopped"
else
  show_help
fi




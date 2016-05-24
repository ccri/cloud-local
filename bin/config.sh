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
  return 1
fi

# [Tab] shell completion because i'm lazy
IFS=$'\n' complete -W "init start stop reconfigure clean help" cloud-local.sh

function validate_config {
  # todo validate versions?
  # allowed versions are hadoop 2.[567].x, zk 3.4.[56], acc 1.6.x
  local pkg_error=""
  if [[ -z "$pkg_hadoop_ver" || ! $pkg_hadoop_ver =~ 2[.][567][.]. ]]; then
    pkg_error="Invalid hadoop version: '${pkg_hadoop_ver}'"
  elif [[ -z "$pkg_zookeeper_ver" || ! $pkg_zookeeper_ver =~ 3[.]4[.][56] ]]; then
    pkg_error="Invalid zookeeper version: '${pkg_zookeeper_ver}'"
  elif [[ -z "$pkg_accumulo_ver" || ! $pkg_accumulo_ver =~ 1[.]6[.]. ]]; then
    pkg_error="Invalid accumulo version: '${pkg_accumulo_ver}'"
  elif [[ -z "$pkg_kafka_ver" || ! $pkg_kafka_ver =~ 0[.]9[.].+ ]]; then
    pkg_error="Invalid kafka version: '${pkg_kafka_ver}'"
  fi
  
  if [[ ! -z "$pkg_error" ]]; then
    echo "ERROR: ${pkg_error}"
    return 1
  else
    return 0
  fi
}

function set_env_vars {
  export ZOOKEEPER_HOME="${CLOUD_HOME}/zookeeper-${pkg_zookeeper_ver}"

  export KAFKA_HOME="${CLOUD_HOME}/kafka_2.11-${pkg_kafka_ver}"
  
  export HADOOP_HOME="$CLOUD_HOME/hadoop-${pkg_hadoop_ver}"
  export HADOOP_PREFIX="${HADOOP_HOME}"
  export HADOOP_CONF_DIR="${HADOOP_PREFIX}/etc/hadoop"
  export HADOOP_COMMON_HOME="${HADOOP_HOME}"
  export HADOOP_HDFS_HOME="${HADOOP_HOME}"
  export HADOOP_YARN_HOME="${HADOOP_HOME}"
  export HADOOP_PID_DIR="${CLOUD_HOME}/data/hadoop/pid"
  export HADOOP_IDENT_STRING=$(echo ${CLOUD_HOME} | md5sum)

  export YARN_HOME="${HADOOP_HOME}" 
  export YARN_PID_DIR="${HADOOP_PID_DIR}"
  export YARN_IDENT_STRING="${HADOOP_IDENT_STRING}"

  export ACCUMULO_HOME="$CLOUD_HOME/accumulo-${pkg_accumulo_ver}"

  export SPARK_HOME="$CLOUD_HOME/spark-${pkg_spark_ver}-bin-hadoop${pkg_spark_hadoop_ver}"
  
  export PATH=$ZOOKEEPER_HOME/bin:$KAFKA_HOME/bin:$ACCUMULO_HOME/bin:$HADOOP_HOME/sbin:$HADOOP_HOME/bin:$SPARK_HOME/bin:$PATH
}

if [[ -z "$JAVA_HOME" ]];then
  echo "ERROR: must set JAVA_HOME..."
  return 1
fi

# load configuration scripts
. "${CLOUD_HOME}/conf/cloud-local.conf"
validate_config
set_env_vars



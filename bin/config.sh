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
IFS=$'\n' complete -W "init start stop reconfigure regeoserver reyarn clean help" cloud-local.sh
NL=$'\n'

function validate_config {
  # allowed versions are hadoop 2.[567].x, zk 3.4.[56], acc 1.[67].x
  local pkg_error=""
  if [[ -z "$pkg_hadoop_ver" || ! $pkg_hadoop_ver =~ 2[.][567][.]. ]]; then
    pkg_error="${pkg_error}Invalid hadoop version: '${pkg_hadoop_ver}' ${NL}"
  fi
  if [[ -z "$pkg_zookeeper_ver" || ! $pkg_zookeeper_ver =~ 3[.]4[.][56789] ]]; then
    pkg_error="${pkg_error}Invalid zookeeper version: '${pkg_zookeeper_ver}' ${NL}"
  fi
  if [[ -z "$pkg_accumulo_ver" || ! $pkg_accumulo_ver =~ 1[.][67][.]. ]]; then
    pkg_error="${pkg_error}Invalid accumulo version: '${pkg_accumulo_ver}' ${NL}"
  fi
  if [[ -z "$pkg_kafka_ver" || ! $pkg_kafka_ver =~ 0[.]9[.].+ ]]; then
    pkg_error="${pkg_error}Invalid kafka version: '${pkg_kafka_ver}' ${NL}"
  fi
  if [[ -z "$pkg_geomesa_scala_ver" && $pkg_geomesa_ver =~ 1[.]3[.].+ ]]; then
    pkg_error="${pkg_error}Invalid GeoMesa Scala version: '${pkg_geomesa_scala_ver}' ${NL}"
  fi
  
  if [[ ! -z "$pkg_error" ]]; then
    echo "ERROR: ${pkg_error}"
    return 1
  else
    return 0
  fi
}

function set_env_vars {
  if [[ $zeppelin_enabled -eq "1" ]]; then
    export ZEPPELIN_HOME="${CLOUD_HOME}/zeppelin-${pkg_zeppelin_ver}-bin-all"
  fi

  if [[ $geomesa_enabled -eq "1" ]]; then
    unset GEOMESA_HOME
    unset GEOMESA_BIN
    export GEOMESA_HOME="${CLOUD_HOME}/geomesa-accumulo_${pkg_geomesa_scala_ver}-${pkg_geomesa_ver}"
    export GEOMESA_BIN="${GEOMESA_HOME}/bin:"
    echo "Setting GEOMESA_HOME:  ${GEOMESA_HOME}"
  fi

  export ZOOKEEPER_HOME="${CLOUD_HOME}/zookeeper-${pkg_zookeeper_ver}"

  export KAFKA_HOME="${CLOUD_HOME}/kafka_2.11-${pkg_kafka_ver}"
  
  export HADOOP_HOME="$CLOUD_HOME/hadoop-${pkg_hadoop_ver}"
  export HADOOP_PREFIX="${HADOOP_HOME}"
  export HADOOP_CONF_DIR="${HADOOP_PREFIX}/etc/hadoop"
  export HADOOP_COMMON_HOME="${HADOOP_HOME}"
  export HADOOP_HDFS_HOME="${HADOOP_HOME}"
  export HADOOP_YARN_HOME="${HADOOP_HOME}"
  export HADOOP_PID_DIR="${CLOUD_HOME}/data/hadoop/pid"
  export HADOOP_IDENT_STRING=$(echo ${CLOUD_HOME} | (md5sum 2>/dev/null || md5) | cut -c1-32)

  export YARN_HOME="${HADOOP_HOME}" 
  export YARN_PID_DIR="${HADOOP_PID_DIR}"
  export YARN_IDENT_STRING="${HADOOP_IDENT_STRING}"

  export SPARK_HOME="$CLOUD_HOME/spark-${pkg_spark_ver}-bin-${pkg_spark_hadoop_ver}"

  export GEOSERVER_DATA_DIR="${CLOUD_HOME}/data/geoserver"
  export GEOSERVER_PID_DIR="${GEOSERVER_DATA_DIR}/pid"
  export GEOSERVER_LOG_DIR="${GEOSERVER_DATA_DIR}/log"  

  [[ "${acc_enabled}" -eq "1" ]] && export ACCUMULO_HOME="${CLOUD_HOME}/accumulo-${pkg_accumulo_ver}"
  [[ "${hbase_enabled}" -eq "1" ]] && export HBASE_HOME="${CLOUD_HOME}/hbase-${pkg_hbase_ver}"
  
  export PATH="$GEOMESA_BIN"$ZOOKEEPER_HOME/bin:$KAFKA_HOME/bin:$HADOOP_HOME/sbin:$HADOOP_HOME/bin:$SPARK_HOME/bin:$PATH
  [[ "${acc_enabled}" -eq "1" ]] && export PATH="${ACCUMULO_HOME}/bin:${PATH}"
  [[ "${hbase_enabled}" -eq "1" ]] && export PATH="${HBASE_HOME}/bin:${PATH}"
  [[ "${zeppelin_enabled}" -eq "1" ]] && export PATH="${ZEPPELIN_HOME}/bin:${PATH}"

  # This variable requires Hadoop executable, which will fail during certain runs/steps
  [[ "$pkg_spark_hadoop_ver" = "without-hadoop" ]] && export SPARK_DIST_CLASSPATH=$(hadoop classpath 2>/dev/null)

  # Export direnv environment file https://direnv.net/
  env | grep -v PATH | sort > $CLOUD_HOME/.envrc
  echo "PATH=${PATH}" >> $CLOUD_HOME/.envrc
}

if [[ -z "$JAVA_HOME" ]];then
  echo "ERROR: must set JAVA_HOME..."
  return 1
fi

# load configuration scripts
. "${CLOUD_HOME}/conf/cloud-local.conf"
validate_config
set_env_vars



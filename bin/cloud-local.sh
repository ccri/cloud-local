#!/usr/bin/env bash

REPO_BASE=https://repo.locationtech.org/content/repositories/geomesa-releases

# thanks accumulo for these resolutions snippets
# Start: Resolve Script Directory
SOURCE="${BASH_SOURCE[0]}"
while [[ -h "${SOURCE}" ]]; do # resolve $SOURCE until the file is no longer a symlink
   bin="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
   SOURCE="$(readlink "${SOURCE}")"
   [[ "${SOURCE}" != /* ]] && SOURCE="${bin}/${SOURCE}" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
bin="$( cd -P "$( dirname "${SOURCE}" )" && pwd )"
script=$( basename "${SOURCE}" )
# Stop: Resolve Script Directory

# Start: config
. "${bin}"/config.sh

# Check config
if ! validate_config; then
  echo "Invalid configuration"
  exit 1
fi

# check java home
if [[ -z "$JAVA_HOME" ]]; then
  echo "must set JAVA_HOME..."
  exit 1
fi
# Stop: config

# import port checking
. "${bin}"/ports.sh

function download_packages {
  # Is the pre-download packages variable set?
  if [[ ! -z ${pkg_pre_download+x} ]]; then
    # Does that folder actually exist?
    if [[ -d ${pkg_pre_download} ]] ; then
      test -d ${CLOUD_HOME}/pkg || rmdir ${CLOUD_HOME}/pkg
      test -h ${CLOUD_HOME}/pkg && rm ${CLOUD_HOME}/pkg
      ln -s ${pkg_pre_download} ${CLOUD_HOME}/pkg
      echo "Skipping downloads... using ${pkg_pre_download}"
      return 0
    fi
  fi

  # get stuff
  echo "Downloading packages from internet..."
  test -d ${CLOUD_HOME}/pkg || mkdir ${CLOUD_HOME}/pkg

  # check for proxy
  if [[ ! -z ${cl_http_proxy+x} ]]; then
    export http_proxy="${cl_http_proxy}"
  fi

  if [[ ! -z ${http_proxy+x} ]]; then
    echo "Using proxy ${http_proxy}"
  fi

  # GeoMesa
  if [[ "${geomesa_enabled}" -eq "1" ]]; then
    gm="geomesa-accumulo-dist_${pkg_geomesa_scala_ver}-${pkg_geomesa_ver}-bin.tar.gz"
    url="${REPO_BASE}/org/locationtech/geomesa/geomesa-accumulo-dist_${pkg_geomesa_scala_ver}/${pkg_geomesa_ver}/${gm}"
    wget -c -O "${CLOUD_HOME}/pkg/${gm}" "${url}" || { rm -f "${CLOUD_HOME}/pkg/${gm}"; echo "Error downloading: ${CLOUD_HOME}/pkg/${gm}"; errorList="${errorList} ${gm} ${NL}"; };
    gm="geomesa-accumulo-distributed-runtime_${pkg_geomesa_scala_ver}-${pkg_geomesa_ver}.jar"
    url="${REPO_BASE}/org/locationtech/geomesa/geomesa-accumulo-distributed-runtime_${pkg_geomesa_scala_ver}/${pkg_geomesa_ver}/${gm}"
    wget -c -O "${CLOUD_HOME}/pkg/${gm}" "${url}" || { rm -f "${CLOUD_HOME}/pkg/${gm}"; echo "Error downloading: ${CLOUD_HOME}/pkg/${gm}"; errorList="${errorList} ${gm} ${NL}"; };
  fi

  # Scala
  if [[ "${scala_enabled}" -eq "1" ]]; then
    url="http://downloads.lightbend.com/scala/${pkg_scala_ver}/scala-${pkg_scala_ver}.tgz"
    file="${CLOUD_HOME}/pkg/scala-${pkg_scala_ver}.tgz"
    wget -c -O "${file}" "${url}" \
      || { rm -f "${file}"; echo "Error downloading: ${file}"; errorList="${errorList} scala-${pkg_scala_ver}.tgz ${NL}"; };
  fi

  local apache_archive_url="http://archive.apache.org/dist"

  local maven=${pkg_src_maven}

  declare -a urls=("${apache_archive_url}/hadoop/common/hadoop-${pkg_hadoop_ver}/hadoop-${pkg_hadoop_ver}.tar.gz"
                   "${apache_archive_url}/zookeeper/zookeeper-${pkg_zookeeper_ver}/zookeeper-${pkg_zookeeper_ver}.tar.gz")

  if [[ "$spark_enabled" -eq 1 ]]; then
    urls=("${urls[@]}" "${apache_archive_url}/spark/spark-${pkg_spark_ver}/spark-${pkg_spark_ver}-bin-${pkg_spark_hadoop_ver}.tgz")
  fi
  
  if [[ "$kafka_enabled" -eq 1 ]]; then
    urls=("${urls[@]}" "${apache_archive_url}/kafka/${pkg_kafka_ver}/kafka_${pkg_kafka_scala_ver}-${pkg_kafka_ver}.tgz")
  fi

  if [[ "$acc_enabled" -eq 1 ]]; then
    urls=("${urls[@]}" "${maven}/org/apache/accumulo/accumulo/${pkg_accumulo_ver}/accumulo-${pkg_accumulo_ver}-bin.tar.gz")
  fi

  if [[ "$hbase_enabled" -eq 1 ]]; then
    urls=("${urls[@]}" "${apache_archive_url}/hbase/${pkg_hbase_ver}/hbase-${pkg_hbase_ver}-bin.tar.gz")
  fi

  if [[ "$zeppelin_enabled" -eq 1 ]]; then
    urls=("${urls[@]}" "${apache_archive_url}/zeppelin/zeppelin-${pkg_zeppelin_ver}/zeppelin-${pkg_zeppelin_ver}-bin-all.tgz")
  fi

  for x in "${urls[@]}"; do
      fname=$(basename "$x");
      echo "fetching ${x}";
      wget -c -O "${CLOUD_HOME}/pkg/${fname}" "$x" || { rm -f "${CLOUD_HOME}/pkg/${fname}"; echo "Error Downloading: ${fname}"; errorList="${errorList} ${x} ${NL}"; };
  done 

  if [[ -n "${errorList}" ]]; then
    echo "Failed to download: ${NL} ${errorList}";
  fi
}

function unpackage {
  local targs
  if [[ "${CL_VERBOSE}" == "1" ]]; then
    targs="xvf"
  else
    targs="xf"
  fi

  echo "Unpackaging software..."
  [[ "${geomesa_enabled}" -eq "1" ]] \
    && $(cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/geomesa-accumulo-dist_${pkg_geomesa_scala_ver}-${pkg_geomesa_ver}-bin.tar.gz") \
    && echo "Unpacked GeoMesa Tools"
  [[ "${scala_enabled}" -eq "1" ]] \
    && $(cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/scala-${pkg_scala_ver}.tgz") \
    && echo "Unpacked Scala ${pkg_scala_ver}"
  (cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/zookeeper-${pkg_zookeeper_ver}.tar.gz") && echo "Unpacked zookeeper"
  [[ "$acc_enabled" -eq 1 ]] && (cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/accumulo-${pkg_accumulo_ver}-bin.tar.gz") && echo "Unpacked accumulo"
  [[ "$hbase_enabled" -eq 1 ]] && (cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/hbase-${pkg_hbase_ver}-bin.tar.gz") && echo "Unpacked hbase"
  [[ "$zeppelin_enabled" -eq 1 ]] && (cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/zeppelin-${pkg_zeppelin_ver}-bin-all.tgz") && echo "Unpacked zeppelin"
  [[ "$kafka_enabled" -eq 1 ]] && (cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/kafka_${pkg_kafka_scala_ver}-${pkg_kafka_ver}.tgz") && echo "Unpacked kafka"
  [[ "$spark_enabled" -eq 1 ]] && (cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/spark-${pkg_spark_ver}-bin-${pkg_spark_hadoop_ver}.tgz") && echo "Unpacked spark"
  (cd -P "${CLOUD_HOME}" && tar $targs "${CLOUD_HOME}/pkg/hadoop-${pkg_hadoop_ver}.tar.gz") && echo "Unpacked hadoop"
}

function configure {
  mkdir -p "${CLOUD_HOME}/tmp/staging"
  cp -r ${CLOUD_HOME}/templates/* ${CLOUD_HOME}/tmp/staging/

  # accumulo config before substitutions
  [[ "$acc_enabled" -eq 1 ]] && cp $ACCUMULO_HOME/conf/examples/3GB/standalone/* $ACCUMULO_HOME/conf/

  ## Substitute env vars
  sed -i~orig "s#LOCAL_CLOUD_PREFIX#${CLOUD_HOME}#;s#CLOUD_LOCAL_HOSTNAME#${CL_HOSTNAME}#;s#CLOUD_LOCAL_BIND_ADDRESS#${CL_BIND_ADDRESS}#" ${CLOUD_HOME}/tmp/staging/*/*

  if [[ "$acc_enabled" -eq 1 ]]; then
    # accumulo config
    echo "${CL_HOSTNAME}" > ${ACCUMULO_HOME}/conf/gc
    echo "${CL_HOSTNAME}" > ${ACCUMULO_HOME}/conf/masters
    echo "${CL_HOSTNAME}" > ${ACCUMULO_HOME}/conf/tservers
    echo "${CL_HOSTNAME}" > ${ACCUMULO_HOME}/conf/monitor
    echo "${CL_HOSTNAME}" > ${ACCUMULO_HOME}/conf/tracers
  fi

  if [[ "$hbase_enabled" -eq 1 ]]; then
    sed -i~orig "s/\# export HBASE_MANAGES_ZK=true/export HBASE_MANAGES_ZK=false/" "${HBASE_HOME}/conf/hbase-env.sh"
    echo "${CL_HOSTNAME}" > ${HBASE_HOME}/conf/regionservers
  fi

  # Zeppelin configuration
  if [[ "$zeppelin_enabled" -eq 1 ]]; then
    echo "[WARNING]  Zeppelin configuration is only template-based for now!"
  fi

  # hadoop slaves file
  echo "${CL_HOSTNAME}" > ${CLOUD_HOME}/tmp/staging/hadoop/slaves

  # deploy from staging
  echo "Deploying config from staging..."
  test -d $HADOOP_CONF_DIR ||  mkdir $HADOOP_CONF_DIR
  test -d $ZOOKEEPER_HOME/conf || mkdir $ZOOKEEPER_HOME/conf
  [[ "$kafka_enabled" -eq 1 ]] && (test -d $KAFKA_HOME/config || mkdir $KAFKA_HOME/config)
  cp ${CLOUD_HOME}/tmp/staging/hadoop/* $HADOOP_CONF_DIR/
  cp ${CLOUD_HOME}/tmp/staging/zookeeper/* $ZOOKEEPER_HOME/conf/
  [[ "$kafka_enabled" -eq 1 ]] && cp ${CLOUD_HOME}/tmp/staging/kafka/* $KAFKA_HOME/config/
  [[ "$acc_enabled" -eq 1 ]] && cp ${CLOUD_HOME}/tmp/staging/accumulo/* ${ACCUMULO_HOME}/conf/
  [[ "$geomesa_enabled" -eq 1 ]] && cp ${CLOUD_HOME}/pkg/geomesa-accumulo-distributed-runtime_${pkg_geomesa_scala_ver}-${pkg_geomesa_ver}.jar ${ACCUMULO_HOME}/lib/ext/
  [[ "$hbase_enabled" -eq 1 ]] && cp ${CLOUD_HOME}/tmp/staging/hbase/* ${HBASE_HOME}/conf/
  [[ "$zeppelin_enabled" -eq 1 ]] && cp ${CLOUD_HOME}/tmp/staging/zeppelin/* ${ZEPPELIN_HOME}/conf/

  # If Spark doesn't have log4j settings, use the Spark defaults
  if [[ "$spark_enabled" -eq 1 ]]; then
    test -f $SPARK_HOME/conf/log4j.properties && cp $SPARK_HOME/conf/log4j.properties.template $SPARK_HOME/conf/log4j.properties
  fi

  # configure port offsets
  configure_port_offset

  # As of Accumulo 2 accumulo-site.xml is nolonger allowed. To avoid a lot of work rewriting the ports script we'll just use accumulo's converter.
  if [ -f "$ACCUMULO_HOME/conf/accumulo-site.xml" ]; then
    rm -f "$ACCUMULO_HOME/conf/accumulo.properties"
    "$ACCUMULO_HOME/bin/accumulo" convert-config \
      -x "$ACCUMULO_HOME/conf/accumulo-site.xml" \
      -p "$ACCUMULO_HOME/conf/accumulo.properties"
    rm -f "$ACCUMULO_HOME/conf/accumulo-site.xml"
  fi

  # Configure accumulo-client.properties
  if [ -f "$ACCUMULO_HOME/conf/accumulo-client.properties" ]; then
    sed -i "s/.*instance.name=.*$/instance.name=$cl_acc_inst_name/" "$ACCUMULO_HOME/conf/accumulo-client.properties"
    sed -i "s/.*auth.principal=.*$/auth.principal=root/"           "$ACCUMULO_HOME/conf/accumulo-client.properties"
    sed -i "s/.*auth.token=.*$/auth.token=$cl_acc_inst_pass/"       "$ACCUMULO_HOME/conf/accumulo-client.properties"

  fi
  rm -rf ${CLOUD_HOME}/tmp/staging
}

function start_first_time {
  # This seems redundant to config but this is the first time in normal sequence where it will set properly
  [[ "$pkg_spark_hadoop_ver" = "without-hadoop" ]] && export SPARK_DIST_CLASSPATH=$(hadoop classpath)
  # check ports
  check_ports

  # start zk
  echo "Starting zoo..."
  (cd $CLOUD_HOME; $ZOOKEEPER_HOME/bin/zkServer.sh start)

  if [[ "$kafka_enabled" -eq 1 ]]; then
    # start kafka
    echo "Starting kafka..." 
    $KAFKA_HOME/bin/kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties
  fi
  
  # format namenode
  echo "Formatting namenode..."
  $HADOOP_HOME/bin/hdfs namenode -format
  
  # start hadoop
  echo "Starting hadoop..."
  $HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR --daemon start namenode
  $HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR --daemon start secondarynamenode
  $HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR --daemon start datanode
  $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR --daemon start resourcemanager
  $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR --daemon start nodemanager
  
  # Wait for HDFS to exit safemode:
  hdfs_wait_safemode 

  # create user homedir
  echo "Creating hdfs path /user/$USER"
  $HADOOP_HOME/bin/hadoop fs -mkdir -p "/user/$USER"
  
  # sleep 
  sleep 5
  
  if [[ "$acc_enabled" -eq 1 ]]; then
    # init accumulo
    echo "Initializing accumulo"
    $ACCUMULO_HOME/bin/accumulo init --instance-name $cl_acc_inst_name --password $cl_acc_inst_pass

    # sleep
    sleep 5

    # starting accumulo
    echo "Starting accumulo..."
    $ACCUMULO_HOME/bin/accumulo-cluster start
  fi

  if [[ "$hbase_enabled" -eq 1 ]]; then
    # start hbase
    echo "Starting hbase..."
    ${HBASE_HOME}/bin/start-hbase.sh
  fi

  if [[ "$zeppelin_enabled" -eq 1 ]]; then
    # start zeppelin
    echo "Starting zeppelin..."
    ${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh start
  fi

  if [[ "$geoserver_enable" -eq 1 ]]; then
    echo "Initializing geoserver..."
    mkdir -p "${GEOSERVER_DATA_DIR}"
    mkdir "${GEOSERVER_PID_DIR}"
    mkdir "${GEOSERVER_LOG_DIR}"
    touch "${GEOSERVER_PID_DIR}/geoserver.pid"
    touch "${GEOSERVER_LOG_DIR}/std.out"
    start_geoserver
  fi

}

function start_cloud {
  # Check ports
  check_ports
 
  if [[ "$master_enabled" -eq 1 ]]; then
  	# start zk
  	echo "Starting zoo..."
  	(cd $CLOUD_HOME ; zkServer.sh start)

  	if [[ "$kafka_enabled" -eq 1 ]]; then
    	echo "Starting kafka..."
    	$KAFKA_HOME/bin/kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties
  	fi
  
  	# start hadoop
  	echo "Starting hadoop..."
  	hdfs --config $HADOOP_CONF_DIR --daemon start namenode
  	hdfs --config $HADOOP_CONF_DIR --daemon start secondarynamenode
  fi

  if [[ "$worker_enabled" -eq 1 ]]; then
  	hdfs --config $HADOOP_CONF_DIR --daemon start datanode
  fi

  start_yarn
  
  # Wait for HDFS to exit safemode:
  echo "Waiting for HDFS to exit safemode..."
  hdfs_wait_safemode
}

function hdfs_wait_safemode {
  safemode_done=1
  while [[ "$safemode_done" -ne 0 ]]; do
    echo "Waiting for HDFS to exit safemode..."
    hdfs dfsadmin -safemode wait
    safemode_done=$?
    if [[ "$safemode_done" -ne 0 ]]; then
      echo "Safe mode not done...sleeping 1"
      sleep 1;
    fi
  done
  echo "Safemode exited"
}


function start_db {
  if [[ "$acc_enabled" -eq 1 ]]; then
    # starting accumulo
    echo "starting accumulo..."
    $ACCUMULO_HOME/bin/accumulo-cluster start
  fi

  if [[ "$hbase_enabled" -eq 1 ]]; then
    # start hbase
    echo "Starting hbase..."
    ${HBASE_HOME}/bin/start-hbase.sh
  fi

  if [[ "$zeppelin_enabled" -eq 1 ]]; then
    # start zeppelin
    echo "Starting zeppelin..."
    ${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh start
  fi

  if [[ "$geoserver_enable" -eq 1 ]]; then
    echo "Starting geoserver..."
    start_geoserver
  fi

}

function start_yarn {
  if [[ "$master_enabled" -eq 1 ]]; then
    $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR --daemon start resourcemanager
  fi 
  if [[ "$worker_enabled" -eq 1 ]]; then
  	$HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR --daemon start nodemanager
  fi 
}

function start_geoserver {
  (${GEOSERVER_HOME}/bin/startup.sh &> ${GEOSERVER_LOG_DIR}/std.out) &
  GEOSERVER_PID=$!
  echo "${GEOSERVER_PID}" > ${GEOSERVER_PID_DIR}/geoserver.pid
  echo "GeoServer Process Started"
  echo "PID: ${GEOSERVER_PID}"
  echo "GeoServer Out: ${GEOSERVER_LOG_DIR}/std.out"
}

function stop_db {
  verify_stop

  if [[ "$zeppelin_enabled" -eq 1 ]]; then
    echo "Stopping zeppelin..."
    ${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh stop
  fi

  if [[ "$kafka_enabled" -eq 1 ]]; then
    echo "Stopping kafka..."
    $KAFKA_HOME/bin/kafka-server-stop.sh
  fi

  if [[ "$acc_enabled" -eq 1 ]]; then
    echo "Stopping accumulo..."
    $ACCUMULO_HOME/bin/accumulo-cluster stop
  fi

  if [[ "$hbase_enabled" -eq 1 ]]; then
    echo "Stopping hbase..."
    ${HBASE_HOME}/bin/stop-hbase.sh
  fi
}

function stop_cloud {
  echo "Stopping yarn and dfs..."
  stop_yarn

  if [[ "$master_enabled" -eq 1 ]]; then
  	$HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR --daemon stop namenode
  	$HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR --daemon stop secondarynamenode
  fi 
  if [[ "$worker_enabled" -eq 1 ]]; then
  	$HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR --daemon stop datanode
  fi 
  echo "Stopping zookeeper..."
  $ZOOKEEPER_HOME/bin/zkServer.sh stop

  if [[ "${geoserver_enabled}" -eq "1" ]]; then
    echo "Stopping geoserver..."
    stop_geoserver
  fi

}

function psux {
  ps ux | grep -i "$1"
}

function verify_stop {
  # Find Processes
  local zeppelin=`psux "[z]eppelin"`
  local kafka=`psux "[k]afka"`
  local accumulo=`psux "[a]ccumulo"`
  local hbase=`psux "[h]base"`
  local yarn=`psux "[y]arn"`
  local zookeeper=`psux "[z]ookeeper"`
  local hadoop=`psux "[h]adoop"`
  local geoserver=`psux "[g]eoserver"`

  local res="$zeppelin$kafka$accumulo$hbase$yarn$zookeeper$geoserver"
  if [[ -n "${res}" ]]; then
    echo "The following services do not appear to be shutdown:"
    if [[ -n "${zeppelin}" ]]; then
      echo "${NL}Zeppelin"
      psux "[z]eppelin"
    fi
    if [[ -n "${kafka}" ]]; then
      echo "${NL}Kafka"
      psux "[k]afka"
    fi
    if [[ -n "${accumulo}" ]]; then
      echo "${NL}Accumulo"
      psux "[a]ccumulo"
    fi
    if [[ -n "${hbase}" ]]; then
      echo "${NL}HBase"
      psux "[h]base"
    fi
    if [[ -n "${yarn}" ]]; then
      echo "${NL}Yarn"
      psux "[y]arn"
    fi
    if [[ -n "${zookeeper}" ]]; then
      echo "${NL}Zookeeper"
      psux "[z]ookeeper"
    fi
    if [[ -n "${hadoop}" ]]; then
      echo "${NL}Hadoop"
      psux "[h]adoop"
    fi
    if [[ -n "${geoserver}" ]]; then
      echo "${NL}GeoServer"
      psux "[g]eoserver"
    fi
    read -r -p "Would you like to continue? [Y/n] " confirm
    confirm=$(echo $confirm | tr '[:upper:]' '[:lower:]') #lowercasing
    if [[ $confirm =~ ^(yes|y) || $confirm == "" ]]; then
      return 0
    else
      exit 1
    fi
  fi
}

function stop_yarn {
  $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR --daemon stop resourcemanager
  $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR --daemon stop nodemanager
}

function stop_geoserver {
  GEOSERVER_PID=`cat ${GEOSERVER_PID_DIR}/geoserver.pid`
  if [[ -n "${GEOSERVER_PID}" ]]; then
    kill -15 ${GEOSERVER_PID}
    echo "TERM signal sent to process PID: ${GEOSERVER_PID}"
  else
    echo "No GeoServer PID was saved. This script must be used to start GeoServer in order for this script to be able to stop it."
  fi
}

function clear_sw {
  [[ "$zeppelin_enabled" -eq 1 ]] && rm -rf "${CLOUD_HOME}/zeppelin-${pkg_zeppelin_ver}-bin-all"
  [[ "$acc_enabled" -eq 1 ]] && rm -rf "${CLOUD_HOME}/accumulo-${pkg_accumulo_ver}"
  [[ "$hbase_enabled" -eq 1 ]] && rm -rf "${CLOUD_HOME}/hbase-${pkg_hbase_ver}"
  [[ -d "${CLOUD_HOME}/geomesa-accumulo_${pkg_geomesa_scala_ver}-${pkg_geomesa_ver}"  ]] && rm -rf "${CLOUD_HOME}/geomesa-accumulo_${pkg_geomesa_scala_ver}-${pkg_geomesa_ver}"
  rm -rf "${CLOUD_HOME}/hadoop-${pkg_hadoop_ver}"
  rm -rf "${CLOUD_HOME}/zookeeper-${pkg_zookeeper_ver}"
  [[ "$kafka_enabled" -eq 1 ]] && rm -rf "${CLOUD_HOME}/kafka_${pkg_kafka_scala_ver}-${pkg_kafka_ver}"
  rm -rf "${CLOUD_HOME}/spark-${pkg_spark_ver}-bin-${pkg_spark_hadoop_ver}"
  rm -rf "${CLOUD_HOME}/scala-${pkg_scala_ver}"
  rm -rf "${CLOUD_HOME}/tmp"
  if [[ -a "${CLOUD_HOME}/zookeeper.out" ]]; then rm "${CLOUD_HOME}/zookeeper.out"; fi #hahahaha
}

function clear_data {
  read -r -p "Are you sure you want to clear data directories? [y/N] " confirm
  confirm=$(echo $confirm | tr '[:upper:]' '[:lower:]') #lowercasing
  if [[ $confirm =~ ^(yes|y) ]]; then
    rm -rf ${CLOUD_HOME}/data/yarn/*
    rm -rf ${CLOUD_HOME}/data/zookeeper/*
    rm -rf ${CLOUD_HOME}/data/dfs/data/*
    rm -rf ${CLOUD_HOME}/data/dfs/name/*
    rm -rf ${CLOUD_HOME}/data/hadoop/tmp/*
    rm -rf ${CLOUD_HOME}/data/hadoop/pid/*
    rm -rf ${CLOUD_HOME}/data/geoserver/pid/*
    rm -rf ${CLOUD_HOME}/data/geoserver/log/*
    if [[ -d "${CLOUD_HOME}/data/kafka-logs" ]]; then rm -rf ${CLOUD_HOME}/data/kafka-logs; fi # intentionally to clear dot files
  fi
}

function show_help {
  echo "Provide 1 command: (init|start|stop|reconfigure|restart|reyarn|regeoserver|clean|download_only|init_skip_download|help)"
  echo "If the environment variable GEOSERVER_HOME is set then the parameter '-gs' may be used with 'start' to automatically start/stop GeoServer with the cloud."
}

if [[ "$2" == "-gs" ]]; then
  if [[ -n "${GEOSERVER_HOME}" && -e $GEOSERVER_HOME/bin/startup.sh ]]; then
      geoserver_enabled=1
  else
    echo "The environment variable GEOSERVER_HOME is not set or is not valid."
  fi
fi

if [[ "$#" -ne 1 && "${geoserver_enabled}" -ne "1" ]]; then
  show_help
  exit 1
fi

if [[ $1 == 'init' ]]; then
  download_packages && unpackage && configure && start_first_time
elif [[ $1 == 'reconfigure' ]]; then
  echo "reconfiguring..."
  #TODO ensure everything is stopped? prompt to make sure?
  stop_cloud && clear_sw && clear_data && unpackage && configure && start_first_time
elif [[ $1 == 'clean' ]]; then
  echo "cleaning..."
  clear_sw && clear_data
  echo "cleaned!"
elif [[ $1 == 'start' ]]; then
  echo "Starting cloud..."
  start_cloud && start_db
  echo "Cloud Started"
elif [[ $1 == 'stop' ]]; then
  echo "Stopping Cloud..."
  stop_db && stop_cloud
  echo "Cloud stopped"
elif [[ $1 == 'start_db' ]]; then
  echo "Starting cloud..."
  start_db
  echo "Database Started"
elif [[ $1 == 'stop_db' ]]; then
  echo "Stopping Database..."
  stop_db
  echo "Cloud stopped"
elif [[ $1 == 'start_hadoop' ]]; then
  echo "Starting Hadoop..."
  start_cloud
  echo "Cloud Hadoop"
elif [[ $1 == 'stop_hadoop' ]]; then
  echo "Stopping Hadoop..."
  stop_cloud
  echo "Hadoop stopped"
elif [[ $1 == 'reyarn' ]]; then
  echo "Stopping Yarn..."
  stop_yarn
  echo "Starting Yarn..."
  start_yarn
elif [[ $1 == 'regeoserver' ]]; then
  stop_geoserver
  start_geoserver
elif [[ $1 == 'restart' ]]; then
  stop_geoserver && stop_cloud && start_cloud && start_geoserver
elif [[ $1 == 'download_only' ]]; then
  download_packages
elif [[ $1 == 'init_skip_download' ]]; then
  unpackage && configure && start_first_time
else
  show_help
fi




#!/usr/bin/env bash

#download relevant jars

source .env

# get stuff
echo "Downloading packages from internet..."
mkdir $CLOUD_HOME/pkg
mirror="http://mirrors.ibiblio.org"
declare -a urls=("$mirror/apache/accumulo/1.6.4/accumulo-1.6.4-bin.tar.gz"
                 "$mirror/apache/hadoop/common/hadoop-2.6.3/hadoop-2.6.3.tar.gz"
                 "$mirror/apache/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz") 

for x in "${urls[@]}"; do
    fname=$(basename "$x");
    echo "fetching ${x}";
    wget -O "$CLOUD_HOME/pkg/${fname}" "$x";
done

echo "Unpackaging software..."
tar xvf $CLOUD_HOME/pkg/zookeeper-3.4.6.tar.gz
tar xvf $CLOUD_HOME/pkg/accumulo-1.6.4-bin.tar.gz
tar xvf $CLOUD_HOME/pkg/hadoop-2.6.3.tar.gz

# Substitute env vars
sed -i "s#LOCAL_CLOUD_PREFIX#$CLOUD_HOME#" $CLOUD_HOME/templates/*/*

echo "Deploying config..."
cp $CLOUD_HOME/templates/hadoop/* $HADOOP_CONF_DIR/
cp $CLOUD_HOME/templates/zookeeper/* $ZOOKEEPER_HOME/conf/

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
hadoop fs -mkdir -p "/user/$USER"

# create accumulo config
cp $ACCUMULO_HOME/conf/examples/3GB/standalone/* $ACCUMULO_HOME/conf/

# init accumulo
echo "Initializing accumulo"
$ACCUMULO_HOME/bin/accumulo init

# starting accumulo
echo "starting accumulo..."
$ACCUMULO_HOME/bin/start-all.sh


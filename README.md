# cloud-local

Cloud-local is a collection of bash scripts to set up a single-node cloud on on your desktop, laptop, or NUC. Performance expectations are to be sufficient for testing things like map-reduce ingest, converters in real life with real files, and your own geoserver/iterator stack. This setup is preconfigured to run YARN so you can submit command line tools mapreduce jobs to it. Currently localhost ssh is NOT required so it will work on a NUC. 

Cloud Local can be used to run single node versions of the following software:
* Hadoop HDFS
* YARN
* Accumulo
* HBase
* Spark (on yarn)
* Kafka
* GeoMesa

## Getting Started 

To prepare for the first run of cloud-local, you may need to `unset` environment variables `HADOOP_HOME`, `ACCUMULO_HOME`, `ZOOKEEPER_HOME`, `HBASE_HOME`, and others. If `env |grep -i hadoop` comes back empty, you should be good to go. You should also `kill` any instances of zookeeper or hadoop running locally. Find them with `jps -lV`.

When using this the first time...

    git clone git@github.com:ccri/cloud-local.git
    cd cloud-local
    bin/cloud-local.sh init

By default only HDFS is started. Edit `conf/cloud-local.conf` to enable Accumulo, BHase, Kafka, GeoMesa, Spark and/or Zeppelin.

Cloud local sets a default accumulo instance name of "local" and password of "secret" which can be modified by editing the `conf/cloud-local.conf` file. If you want to change this you'll need to stop, clean, and reconfigure.

This init script does several things:
* configure HDFS configuration files
* format the HDFS namenode
* create a user homedir in hdfs
* initialize accumulo/hbase
* start up zookeeper, hadoop, and accumulo/hbase
* start kafka broker
* install and start Zeppelin
* install GeoMesa Accumulo iterators
* install GeoMesa command-line tools

After running `init` source the variables in your bashrc or other shell:

    source bin/config.sh

Now you should have the environment vars set:
    
    env | grep -i hadoop

Now you can run fun commands like:

    hadoop fs -ls /
    accumulo shell -u root 

After installing it you should be able to reach your standard cloud urls:

* Accumulo:    http://localhost:50095
* Hadoop DFS:  http://localhost:50070
* Job Tracker: http://localhost:8088
* Zeppelin:    http://localhost:5771

## Getting Help

Options for using `cloud-local.sh` can be found by calling:

    bin/cloud-local.sh help

You can also set `CL_VERBOSE=1` env variable in `conf/cloud-local.conf` to increase messages

## Stopping and Starting

You can safely stop the cloud using: 

    bin/cloud-local.sh stop

You should stop the cloud before shutting down the machine or doing maintenance.

You can start the cloud back up using the analogous `start` option. Be sure that the cloud is not running (hit the cloud urls or `ps aux|grep -i hadoop`).

    bin/cloud-local.sh start

If existing ports are bound to the ports needed for cloud-local an error message will be printed and the script will stop.

## Changing Ports, Hostname, and Bind Address

cloud-local allows you to modify the ports, hostname, and bind addresses in configuration or using variables in your env (bashrc). For example:

    # sample .bashrc configuration
    
    # offset all ports by 10000
    export CL_PORT_OFFSET=10000
    
    # change the bind address
    export CL_BIND_ADDRESS=192.168.2.2
    
    # change the hostname from localhost to something else
    export CL_HOSTNAME=mydns.mycompany.com
    
Port offseting moves the entire port space by a given numerical amount in order to allow multiple cloud-local instances to run on a single machine (usually by different users). The bind address and hostname args allow you to reference cloud local from other machines.

WARNING - you should stop and clean cloud-local before changing any of these parameters since they will modify the config and may prevent cloud-local from cleanly shutting down. Changing port offsets is supported by XML comments in the accumulo and hadoop config files. Removing or changing these comments (CL_port_default) will likely cause failures.

## GeoServer

If you have the environment variable GEOSERVER_HOME set you can use this parameter to start GeoServer at the same time but running in a child thread.

    bin/cloud-local.sh start -gs

Similarly, you can instruct cloud-local to shutdown GeoServer with the cloud using:

    bin/cloud-local.sh stop -gs
    
Additionally, if you need to restart GeoServer you may use the command `regeoserver`:

    bin/cloud-local.sh regeoserver
    
The GeoServer PID is stored in `$CLOUD_HOME/data/geoserver/pid/geoserver.pid` and GeoServer's stdout is redirected to `$CLOUD_HOME/data/geoserver/log/std.out`.

## Zeppelin

Zeppelin is *disabled* by default.

Currently, we are using the Zeppelin distribution that includes all of the interpreters, and
it is configured to run against Spark only in local mode.  If you want to connect to another
(real) cloud, you will have to configure that manually; see:

[Zeppelin documentation](http://zeppelin.apache.org/docs/0.7.0/install/spark_cluster_mode.html#spark-on-yarn-mode)

### GeoMesa Spark-SQL on Zeppelin

To enable GeoMesa's Spark-SQL within Zeppelin:

1.  point your browser to your [local Zeppelin interpreter configuration](http://localhost:5771/#/interpreter)
1.  scroll to the bottom where the *Spark* interpreter configuration appears
1.  click on the "edit" button next to the interpreter name (on the right-hand side of the UI)
1.  within the _Dependencies_ section, add this one JAR (either as a full, local file name or as Maven GAV coordinates):
    1.  geomesa-accumulo-spark-runtime_2.11-1.3.0.jar
1.  when prompted by the pop-up, click to restart the Spark intepreter

That's it!  There is no need to restart any of the cloud-local services.

## Maintenance

The `cloud-local.sh` script provides options for maintenance. Best to stop the cloud before performing any of these tasks. Pass in the parameter `clean` to remove software (but not the tar.gz's) and data. The parameter `reconfigure` will first `clean` then `init`.

### Updating

When this git repo is updated, follow the steps below. The steps below will remove your data. 

    cd $CLOUD_HOME
    bin/cloud-local.sh stop
    bin/cloud-local.sh clean
    git pull
    bin/cloud-local.sh init

### Starting over

If you foobar your cloud, you can just delete everything and start over. You should do this once a week or so just for good measure.  

    cd $CLOUD_HOME
    bin/cloud-local.sh stop  #if cloud is running
    rm * -rf
    git pull
    git reset --hard
    bin/cloud-local.sh init

## Virtual Machine Help

If you are using cloud-local within a virtual machine running you your local box you may want to set up port forwarding for port 50095 to see the accumulo monitor. For VirtualBox go to VM's Settings->Network->Port Forwarding section (name=accumulo, protocol=TCP, Host IP=127.0.0.1, Guest IP (leave blank), Guest Port=50095)

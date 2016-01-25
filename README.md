# cloud-local

Cloud-local is a collection of bash scripts to set up a single-node cloud on on your desktop, laptop, or NUC. Performance expectations are to be sufficient for testing things like map-reduce ingest, converters in real life with real files, and your own geoserver/iterator stack. This setup is preconfigured to run YARN so you can submit command line tools mapreduce jobs to it. Currently localhost ssh is NOT required so it will work on a NUC. 

## Getting Started 

To prepare for the first run of cloud-local, you may need to `unset` environment variables `HADOOP_HOME`, `ACCUMULO_HOME` , `ZOOKEEPER_HOME`, and others. If `env |grep -i hadoop` comes back empty, you should be good to go. You should also `kill` any instances of zookeeper or hadoop running locally. Find them with `jps -lV`.

When using this the first time...

    git clone git@github.com:ccri/cloud-local.git
    cd cloud-local
    bin/cloud-local.sh init

You'll be prompted to enter the accumulo instance name and pasword...(hint: try "local" and "secret")

This init script does several things:
* configure HDFS configuration files
* format the HDFS namenode
* create a user homedir in hdfs
* initialize accumulo
* start up zookeeper, hadoop, and accumulo

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

## Getting Help

Options for using `cloud-local.sh` can be found by calling:

    bin\cloud-local.sh help

## Stopping and Starting

You can safely stop the cloud using: 

    bin/cloud-local.sh stop

You should stop the cloud before shutting down the machine or doing maintenance.

You can start the cloud back up using the analogous `start` option. Be sure that the cloud is not running (hit the cloud urls or `ps aux|grep -i hadoop`).

    bin/cloud-local.sh start

If existing ports are bound to the ports needed for cloud-local an error message will be printed and the script will stop.


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

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
* start up zookeeper/hadoop/accumulo

After running init you may want to source the variables in your bashrc or other shell:

    source ~/cloud-local/bin/config.sh

Now you should have the environmental vars set:
    
    env | grep -i hadoop

Now you can run fun commands like:

    hadoop fs -ls /
    accumulo shell -u root -p secret

After installing it you should be able to reach your standard cloud urls:

* Accumulo:    http://localhost:50095
* Hadoop DFS:  http://localhost:50070
* Job Tracker: http://localhost:8088

There are a few other scripts:

* ```bin/start_cloud.sh``` - Start the cloud (make sure it isn't running)
* ```bin/stop_cloud.sh``` - Stop the cloud safely...hopefully

If you foobar you cloud, DELETE IT ALL and checkout from git again.

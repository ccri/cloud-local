When using this the first time...

    git clone git@github.com:ccri/cloud-local.git
    cd cloud-local
    source .env
    ./init.sh

You'll be prompted to enter the accumulo instance name and pasword...(hint: try "local" and "secret")

After running init (and make sure you sourced the .env file to get your path right!), try running:

    hadoop fs -ls /user/yourusername
    accumulo shell -u root -p secret

This init script does several things:
* configure HDFS configuration files
* format the HDFS namenode
* create a user homedir in hdfs
* initialize accumulo (you'll be prompted to entire password and instance name...try "local" for the instance and "secret" for the password)
* start up zookeeper/hadoop/accumulo

After installing it you should be able to reach your standard cloud urls:

* Accumulo:    http://localhost:50095
* Hadoop DFS:  http://localhost:50070
* Job Tracker: http://localhost:8088

There are a few other scripts:

* ```.\start_cloud.sh``` - Start the cloud (make sure it isn't running)
* ```.\stop_cloud.sh``` - Stop the cloud safely...hopefully

If you foobar you cloud, DELETE IT ALL and checkout from git again.

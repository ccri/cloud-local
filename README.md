When using this the first time:

    cd cloud-local
    ./init.sh

This init script will:
* configure HDFS configuration files
* format the HDFS namenode
* create a user homedir in hdfs
* initialize accumulo (you'll be prompted to entire password and instance name...try "local" for the instance and "secret" for the password)
* start up zookeeper/hadoop/accumulo



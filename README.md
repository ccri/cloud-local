When using this the first time...

    git clone git@github.com:ccri/cloud-local.git
    cd cloud-local
    source .env
    ./init.sh

You'll be prompted to enter the accumulo instance name and pasword...

After running init (and make sure you sourced the .env file to get your path right!), try running:

    hadoop fs -ls /user/yourusername
    accumulo shell -u root -p secret

This init script does several things:
* configure HDFS configuration files
* format the HDFS namenode
* create a user homedir in hdfs
* initialize accumulo (you'll be prompted to entire password and instance name...try "local" for the instance and "secret" for the password)
* start up zookeeper/hadoop/accumulo


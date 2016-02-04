# UDEV Cloud Installation Logbook

## Why deploy to Udev?

It is the old pcloud, so there has to be some cloud there right??? There are two main reasons why I'm deploying to Udev, though all of this should work on any NUC. 

1. Other people can hit these servers/services & it is more powerful than a NUC
2. I can remote into it. (If the NUCs got ssh I would be very happy.


## Deploying Cloud Local to Udev
Fairly straight forward, as intended by ahulbs. I checked out a testing branch that also includes Kafka, since I use kafka so much. So there are some slight modifications that I found that were easy fixes, but can be frustrating for the first time cloud user.

```bash
git clone git@github.com:ccri/cloud-local.git
cd cloud-local
git checkout f_kafka # Branch with Kafka deployed as well...
nano bin/cloud-local
# In function download_packages(), change the declare -a urls line and remove the trailing slash for the accumulo line. Example below
#      declare -a urls=("${maven}/org/apache/accumulo......  TO declare -a urls=("${maven}org/apache/accumulo........

# In function configure, I found that both conf dirs already existed and as such you need to comment out the folder creation lines
# Comment out the following:
#     test -d $HADOOP_CONF_DIR && mkdir $HADOOP_CONF_DIR
#     test -d $ZOOKEEPER_HOME/conf && mkdir $ZOOKEEPER_HOME/conf

bin/cloud-local.sh init

nano ~/.bashrc 
# Source the environment vars like ahulbs tells you to!
# source /path/to/cloud-local/bin/config.sh
```

The commands to run/stop cloud-local is simple /path/to/cloud-local/cloud-local.sh start|stop

Minus the changes to the f_kafka branch, this is all documented at the [Github Page](https://github.com/ccri/cloud-local)


## Compiling GeoMesa (1.2.0-SNAPSHOT or later) with Java 8

Very straight forward, though might take awhile to compile (10 minutes probably on the long side). I skipped tests for brevity.

Note: Compiling with Java 8 seems to be a non-issue. However, it would appear that many things have been depreceated, which it catches and compiles correctly. If a move is made to make 8 the standard, then there might be some work to tidy that up. Again, it works just fine for 8 but 9 might break based on depreciated calls.

```bash 
git clone https://github.com/locationtech/geomesa.git
# I'm compiling against no releases because 1.2.0 hasn't been cut even as a release candidate.
# You might need to checkout a 1.2.0 release or later (Advised).
cd geomesa
mvn clean install -DskipTests=true
```

Now this compiles *all* of geomesa, which is great for development and deployment in all forms. In most cases however we will only need the distribution produced in compilation.

I rename our current geomesa folder to geomesa_src just so I can unpack the actual distribution as geomesa
```bash
mv geomesa geomesa_src
tar -xvf geomesa_src/geomesa-dist/target/geomesa-1.2.0-SNAPSHOT-bin.tar.gz -C . # Unpack the dist
mv geomesa-1.2.0-SNAPSHOT/ geomesa # Rename the folder for brevity
```

Now we have a geomesa_src folder for updates / releases and we can simply unpack a new distribution as we recompile!

Unfortunately, we are not quite done. We now have to configure the geomesa-tools. So now we are going to unpack the geomesa-tools and configure!

``bash
cd geomesa/dist/tools
tar -xvf geomesa-tools-1.2.0-SNAPSHOT-bin.tar.gz
cd geomesa-tools-1.2.0-SNAPSHOT/
bin/geomesa configure
# Normally you should just be able to enter Y or press enter for the two options. Make sure the path is right
# After config you need to enter the two lines in your bashrc, should look like:
# export GEOMESA_HOME=/path/to/geomesa/dist/tools/geomesa-tools-1.2.0-SNAPSHOT
# export PATH=${GEOMESA_HOME}/bin:$PATH
```

Now we have to install non-free dependencies. Easy enough by running:
```bash
bin/install-jai
bin/install-jline
bin/install-vecmath
```

I ran into this issue working on Udev with multiple geomesa deployments by multiple users. There is a fix upstream for geomesa, but you should check that this is correct if you are working on udev or multiuser environments.

Edit bin/geomesa.
- Change: GEOMESA_OPTS="-Duser.timezone=UTC"
- To: GEOMESA_OPTS="-Duser.timezone=UTC -DEPSG-HSQL.directory=/tmp/$(whoami)"


At this point, Geomesa should be ready to role! For a sanity check, there is a bin/test-geomesa script. You need to configure the script first. All the things in ALL_CAPS need to be set. Below is a list with values I put in:

- USER=root # Accumulo User
- PASS=password # Accumulo Password
- CREATE_CATALOG=test_catalog # A catalog to create
- CREATE_FEATURENAME=test_feature # A feature to create in the catalog
- SPEC # I left that the same
- CATALOG=${CREATE_CATALOG} # It has to exist, so I set it to the one I created
- FEATURENAME=${CREATE_FEATURENAME} # It has to exist, so I set it to the one I created
- INST=accumulo_name # Name of the Accumulo Instance
- ZOO=localhost # Zookeeper names, localhost for cloud-local

Then you can run bin/test-geomesa. It should run without too many errors, max-features seems to have been depreciated so those through errors but it still runs. 


## Geomesa -- Accumulo Jar Deployment

Now that we have Accumulo in cloud-local and Geomesa up and running, we now have to put the Geomesa dependencies for Accumulo to find. Usually you would need to put the Geomesa jars in every Accumulo instance in the cluster but since we are using cloud-local there is only one accumulo instance to find. 

If the cloud-local folder and the geomesa folder are in the same director then:

```bash
cp geomesa/dist/accumulo/geomesa-accumulo-distributed-runtime-1.2.0-SNAPSHOT.jar cloud-local/accumulo-1.6.4/lib/ext/
```

That's it! Make sure to restart Accumulo



This guide is mostly everything here: [GUIDE](http://www.geomesa.org/documentation/test-readthedocs/user/installation_and_configuration.html#install-geoserver-plugins)


## Setting up Wildfly 9.0.2

Download the Wildfly distribution from their [website](http://wildfly.org/downloads/). Download the full distribution,

Now unpack it and should be able to just run it!

```bash
unzip wildfly-9.0.2.Final.zip 
mv wildfly-9.0.2.Final wildfly
cd wildfly
bin/standalone.sh
```

If you have port 8080 of whatever server you put this on available, you should be able to go to http://localhost:8080/ and see the wildfly welcome page. 

If not, it usually is good enough to run that and see the final line say something like Started 203 of 379 services (# of services varies)

That's it! We will have to do some light configuration once we deploy Geoserver, but not too much.


## Deploying Geoserver (+WPS plugin!!) to Wildfly

The current Geoserver in use for CCRi is 2.5.2 (It is an older version.). So you need to go to the [download page](http://geoserver.org/download/) and download the WAR file version.

To deploy:

```bash
cd /path/to/widfly/standalone/deployments
wget geoserver-2.5.2-war.zip # Or copy it
unzip geoserver-2.5.2-war.zip
unzip geoserver.war -d geoserver # You can deploy a war file as is, but we need to configure geoserver, so it is easier to just unzip it.
rm geoserver-2.5.2-war.zip geoserver.war
mv geoserver geoserver.war # I rename it the war file just for keeping it what it is, just unzipped
touch geoserver.war.dodeploy # Let Wildfly know to deploy this war file
```

Now we need to configure Geoserver. It is fairly straight forward.

```bash
cd /path/to/wildfly/standalone/configuration
nano standalone.xml
# Paste the following AFTER the <extension> block and before the <management> block. Set username
#     <system-properties>
#        <property name="GEOSERVER_DATA_DIR" value="/home/USERNAME/data/geoserver-data"/>
#        <property name="EPSG-HSQL.directory" value="/tmp/USERNAME-custom-hsql"/>
#        <property name="GEOWEBCACHE_CACHE_DIR" value="/tmp/USERNAME-custom-geowebcache"/>
#    </system-properties>
```

Excellent, now we should test to make sure Geoserver installed right. Simply run the run script as above

```bash
cd /path/to/wildfly
bin/standalone.sh
```

You should see a much longer startup message. If you go to 127.0.0.1:8080/geoserver it should now come up! You can log in using username: admin and password: geoserver

### Now we need to deploy an additional plugin that Geoserver produces: WPS. 

LINK FOR OFFICIAL DOC: [HERE](http://docs.geoserver.org/stable/en/user/extensions/wps/install.html)

If you went to the same 2.5.2 download page for Geoserver, you should see an extension section and you need to download the wps plugin. Then you can simply deploy!

Make sure Geoserver isn't running

```bash
cd /path/to/geoserver-2.5.2-wps-plugin.zip
unzip geoserver-2.5.2-wps-plugin.zip -d /path/to/wildfly/standalone/deployments/geoserver.war/WEB-INF/lib/
```

Restart Geoserver, you should now see WPS as a service on the Geoserver home page

## Deploying Geomesa/Kafka to Geoserver!

The Kafka steps are optional. But if you use kafka, then do it. Duh.

With 1.2.0 this is very easy. Mostly. We have to copy several jars from our installs into the Geoserver/WEB-INF/lib folder. Not too hard, but the jars are in several places

```bash
cd /path/to/geomesa/dist/gs-plugins # Oh my, a whole folder just for Geoserver plugins
tar -xzvf geomesa-accumulo-gs-plugin-1.2.0-SNAPSHOT-install.tar.gz -C ~/little-bam/wildfly/standalone/deployments/geoserver.war/WEB-INF/lib/
tar -xzvf geomesa-kafka-gs-plugin-1.2.0-SNAPSHOT-install.tar.gz -C ~/little-bam/wildfly/standalone/deployments/geoserver.war/WEB-INF/lib/
# Now we need extra dependencies!
# For Hadoop/Accumulo geomesa has a script for installing the necessary dependencies
cd /path/to/geomesa/dist/tools/geomesa-tools-1.2.0-SNAPSHOT/bin
./install-hadoop-accumulo.sh /path/to/wildfly/standalone/deployments/geoserver.war/WEB-INF/lib

# Now we need the Kafka depnedencies
# Unfortunately, no nice script but you only need to copy some jars from our Kafka install
cd /path/to/cloud-local/kafka_2.11-0.9.0.0/libs
# Copy the following jars to ~/little-bam/wildfly/standalone/deployments/geoserver.war/WEB-INF/lib
# kafka-clients
# kafka_2.11
# metrics-core
# zkclient
# zookeeper
# Example:
cp kafka-clients-0.9.0.0.jar ~/little-bam/wildfly/standalone/deployments/geoserver.war/WEB-INF/lib/
```

After you copy all of the jars, we need to make sure that Geoserver got everything you needed. If you restart Wildfly, then go to the Geoserver web page and login. Then click on the Add Stores link, on that page you should see under Vector Data Sources Accumulo (GeoMesa) and Kafka Data Store. 

If you did, congrats. If you didn't some jars did not get copied over right. 

## Building Stealth with Java 8

```bash
git clone https://github.com/ccri/stealth.git
cd stealth
nano pom.xml # Change JAVA version restriction from (,1.8) to (,1.9)
mvn clean prepare-package -Pinstall-nodejs,unpack-npm,unpack-bower
mvn clean install -Pproduction
# .war file now in webapp/target
```

## Deploy stealth to Wildfly
```bash
cp stealth/webapp/target/stealth.war /path/to/wildfly/standalone/deployments/
# Restart wildfly, should auto deploy!
```

## Configuring Stealth with an external TypeSafe Config File

In order to config stealth post compile, we need Wildfly to read a TypeSafe Config file. So we need to set a system property in wildfly to read a config file, just for ease of changing configuration for stealth!

1. Point Wildfly to config file

```bash
nano /path/to/wildfly/standalone/configuration/standalone.xml
# In the system-properties section make sure it includes the config.file property, example below
# <system-properties>
#	<property name="config.file" value="/path/to/wildfly/stealth.conf" /> #Or wherever you want the file
# </system-properties>
```

2. Put stuff in the stealth.conf file

```bash
nano /path/to/stealth/conf/file/stealth.conf
# For pointing Stealth to local GeoServer, put in the below piece
# stealth {
#  geoserver {
#    defaultUrl = "http://localhost:8080/geoserver"
#    omitProxy = false
#  }
#}
```

3. Restart Wildfly and Enjoy!




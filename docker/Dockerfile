FROM ubuntu:14.04
MAINTAINER Jason Brown <jason.brown@ccri.com>

RUN \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y software-properties-common && \
  apt-get install -y curl git man unzip vim wget  

# Install Java 7. (https://github.com/dockerfile/java)
RUN \
  echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java7-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk7-installer

# Define JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-7-oracle

# Get cloud-local
ADD bin/* /opt/cloud-local/bin/
ADD conf/* /opt/cloud-local/conf/
ADD templates/hadoop/* /opt/cloud-local/templates/hadoop/
ADD templates/zookeeper/* /opt/cloud-local/templates/zookeeper/
ADD templates/kafka/* /opt/cloud-local/templates/kafka/

# Add targzs at time of build... #TODO extract these from /conf ?
ADD pkg/ /opt/cloud-local/pkg

# Set cloud home and hadoop vars
RUN echo "source /opt/cloud-local/bin/config.sh" >> /root/.bashrc

# Add geomesa 1.2.0 goodies
#ADD http://repo.locationtech.org/content/repositories/geomesa-releases/org/locationtech/geomesa/geomesa-dist/1.2.0/geomesa-dist-1.2.0-bin.tar.gz /opt/cloud-local/pkg

# Expose ports for common cloud urls: accumulo master, hadoop dfs, yarn, mr job history, generic web
EXPOSE 50095
EXPOSE 50070
EXPOSE 8088
EXPOSE 19888
EXPOSE 8042
EXPOSE 8080

# Launch cloud-local, using reconfigure (assumes proper targz's are in $CLOUD_HOME/pkg)
#RUN /opt/cloud-local/bin/cloud-local.sh reconfigure; \
#    /bin/sh -c bash

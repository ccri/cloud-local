FROM  centos:centos6
MAINTAINER Jason Brown <jason.brown@ccri.com>

RUN yum update -y && \ 
    yum install -y wget && \
    wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.rpm" && \
    yum localinstall -y /jdk-7u80-linux-x64.rpm && \
    rm -f /jdk-7u80-linux-x64.rpm 

RUN yum install -y curl git man unzip vim 
RUN yum clean all

# Define JAVA_HOME variable
ENV JAVA_HOME /usr/java/default

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
# ADD http://repo.locationtech.org/content/repositories/geomesa-releases/org/locationtech/geomesa/geomesa-dist/1.2.0/geomesa-dist-1.2.0-bin.tar.gz /opt/cloud-local/pkg

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

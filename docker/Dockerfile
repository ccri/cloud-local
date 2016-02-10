FROM ubuntu:14.04
MAINTAINER Jason Brown <jason.brown@ccri.com>

RUN \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y software-properties-common && \
  apt-get install -y curl git man unzip vim wget  

# Install Java. (https://github.com/dockerfile/java)
RUN \
  echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java7-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk7-installer

# Define JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-7-oracle

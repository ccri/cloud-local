#!/bin/bash

# build docker image; do this the first time at least, it caches so doesn't slow you down much to build every time
cd docker
docker build -t ccri/cloud-local -f Dockerfile ..
# alternatively you can build a centos 6 flavored image
docker build -t ccri/cloud-local:centos6 -f centosDockerfile ..


# run new container from image in terminal mode
# you can optionally pass in --name mycontainername
# Start the container, get the ID
CONTAINER="$(docker run -itdP ccri/cloud-local)"
# CONTAINER="$(docker run -itdP ccri/cloud-local:centos6)" # Centos6

# Start cloud-local in the container
docker exec $CONTAINER /opt/cloud-local/bin/cloud-local.sh reconfigure

# Print running docker containers - includes port mappings into container
docker ps

# attach to new container
docker attach $CONTAINER

# For most things you will need to configure environment variables:
# root@id:/# source /opt/cloud-local/bin/config.sh

# Then CTRL+P CTRL+Q to exit running container as needed; docker attach to get back in

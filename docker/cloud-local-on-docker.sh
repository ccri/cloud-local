#!/bin/bash

# build docker image
cd docker/
docker build -t ccri/cloud-local .

# ensure access to $CLOUD_HOME
cd ..
source bin/config.sh

# run new container from image in terminal mode, attaching cloud-local repo as read only volume 
# you can optionally pass in --name mycontainername
docker run -t -i  -v $CLOUD_HOME:/opt/cloud-local:ro  ccri/cloud-local /bin/bash

# When container starts, to launch cloud-local:
# root@id:/# git clone /opt/cloud-local
# root@id:/# cd /opt/cloud-local
# root@id:/# bin/cloud-local.sh init

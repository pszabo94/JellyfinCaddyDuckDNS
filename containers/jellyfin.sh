#!/bin/bash

podman create --replace \
  --name jellyfin \
  --publish 8096:8096/tcp \
  --network host \
  -e TZ=Europe/Budapest \
  --user 0:0 \
  --group-add=$(getent group render | cut -d: -f3) \
  --device /dev/dri/renderD128:/dev/dri/renderD128:rwm \
  --volume /srv/ctnuser/containers/jellyfin/cache:/cache:Z \
  --volume /srv/ctnuser/containers/jellyfin/config:/config:Z \
  --mount type=bind,source=/srv/ctnuser/storage/media,destination=/media,ro=true,relabel=shared \
  docker.io/jellyfin/jellyfin:latest

#!/bin/bash

podman create --replace \
  --name caddy \
  --publish 443:443/tcp \
  --network slirp4netns \
  -e TZ=Europe/Budapest \
  --user 0:0 \
  --volume /srv/ctnuser/containers/caddy/Caddyfile:/etc/caddy/Caddyfile:z \
  --volume /srv/ctnuser/containers/caddy/data:/data:Z \
  docker.io/serfriz/caddy-duckdns:latest

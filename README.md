# Jellyfin Caddy DuckDNS, mediaserver for everyone, for free. Reachable from everywhere.
## Containerized Jellyfin media server with Caddy (reverse proxy) and DuckDNS.

#### For this setup I use Podman, but if you prefer Docker, feel free to use that. Also, if you are not planning to make it reachable outside of your local network, skip the Caddy, DuckDNS and portforwarding part.

#### So first, I usually open the firewall ports for the services that I'll host:
<pre>firewall-cmd --permanent --add-port=8096/tcp #Jellyfin.
firewall-cmd --permanent --add-port=443/tcp #For reverse proxy (HTTPS), you have to enable port forwarding in your router for this port. Skip, if you do only plan to use it via LAN.
firewall-cmd --reload #Reload to take effect</pre>

#### I like to have a dedicated user, in this case ctnuser, but it is up to you.
<pre>sudo useradd -M ctnuser # Create the user without home directory.
sudo usermod -a -G render,video ctnuser # Add the user to the render and video groups.
sudo mkdir -p /srv/{containers,storage,ctnuser}
sudo mkdir -p /srv/containers/{caddy,jellyfin}
sudo mkdir -p /srv/storage/{downloads,media}
sudo mkdir -p /srv/storage/media/{movies,series}
sudo chown -R ctnuser:ctnuser /srv/ctnuser /srv/containers /srv/storage # Add the ownership to the user.
sudo usermod -d /srv/ctnuser ctnuser # Set the directory as a home for the user.</pre>

#### Caddyfile configuration for DuckDNS. Skip, if you do only plan to use it via LAN.
<pre>sudo vi /srv/containers/caddy/Caddyfile # Do not forget the ownership and access.

  "your_domain".duckdns.org {
    reverse_proxy <your_internal_IP>:8096 
    tls {
    dns duckdns <your_token_from_duckdns> 
    }
  }</pre>

#### Also a script, that updates your IP. Useful if you have a dynamic IP. Skip, if you do only plan to use it via LAN.
<pre>mkdir /srv/ctnuser/scripts
vi duckdns.sh # Do not forget to make it executable.

echo url="https://www.duckdns.org/update?domains="your_domain"&token="your_token_from_duckdns"&ip=" | curl -k -o /srv/ctnuser/scripts/duck.log -K -</pre>

#### Create a crontab entry to run the DuckDNS script every 5 minutes. Skip, if you do only plan to use it via LAN.
<pre>crontab -e
*/5 * * * */srv/ctnuser/scripts/duckdns.sh
</pre>

#### If you have an external hard drive, you can create a permament mountpoint in the fstab. Careful with this.
<pre>sudo vi /etc/fstab

UUID="UUID_of_the_drive" /srv/storage ext4 defaults,noatime 0 2 # A basic mount, modify if you prefer something else.</pre>

#### Now, create the containers, with the container user. With the "create --replace", it is easy to recreate them anytime and overwrite the exiting one.
###### What you need to keep an eye on, is the ":z" and ":Z". These for SELinux. Lowercase means shared, uppercase unshared, very important.
<pre>podman create --replace \
  --name caddy \
  --publish 443:443/tcp \
  --network slirp4netns \
  -e TZ=Europe/Budapest \
  --user 0:0 \
  --volume /srv/containers/caddy/Caddyfile:/etc/caddy/Caddyfile:z \
  --volume /srv/containers/caddy/data:/data:Z \
  docker.io/serfriz/caddy-duckdns:latest


podman create --replace \
  --name jellyfin \
  --publish 8096:8096/tcp \
  --network host \
  -e TZ=Europe/Budapest \
  --user 0:0 \
  --group-add=$(getent group render | cut -d: -f3) \
  --device /dev/dri/renderD128:/dev/dri/renderD128:rwm \
  --volume /srv/containers/jellyfin/cache:/cache:Z \
  --volume /srv/containers/jellyfin/config:/config:Z \
  --mount type=bind,source=/srv/storage/media,destination=/media,ro=true,relabel=shared \
  docker.io/jellyfin/jellyfin:latest</pre>

#### For the last step, we have to set up SELinux to treat these as regular containers.
<pre>sudo semanage fcontext -a -e /var/lib/containers /srv/ctnuser/.local/share/containers
sudo restorecon -R -F/srv/ctnuser/.local/share/containers</pre>

#### Now feel free to try it, play with it.
<pre>podman start caddy
podman start jellyfin</pre>

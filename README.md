# Jellyfin Caddy DuckDNS, a media server for everyone, for free. Reachable from everywhere.
###### This is my first repository and the setup probably can be improved further too. Please feel free to share your thoughts, experience to imporove the setup and my knowledge.
##### For this setup I use Podman, but if you prefer Docker, feel free to use that. Also, if you are not planning to make it reachable outside of your local network, skip the Caddy, DuckDNS and port forwarding part.
##### I don't like automatic updates, so you won't find it in this build. I prefer to update and start the system/containers manually to see if it has an error or not with the new packages.
##### I have this on a Fedora Server 42, but was working fine on openSUSE MicroOS before and should work on any Linux distribution.
##### You can find a step-by-step guide below.

### I suggest to check the Jellyfin documentation and create a DuckDNS domain if you plan to reach your Jellyfin outside of your local network.
<pre>https://jellyfin.org/docs/
https://www.duckdns.org/</pre>

### For the first step, open the firewall ports for the services.
##### Port 8086 is required by Jellyfin, port 443 is required by Caddy for the reverse proxy to have a secure connection (HTTPS). You also have to set port forwarding to this port in your router, but if you do not plan to reach Jellyfin outside of your local network, leave the port 443 as it is and skip the Caddy/DuckDNS part of the configuration.
<pre>sudo firewall-cmd --permanent --add-port=8096/tcp --add-port=443/tcp
sudo firewall-cmd --reload #Reload to take effect.</pre>

### Caddy requires port 443 for revers proxy, so it has to be enabled for unprivileged access. Skip, if you do not plan to reach Jellyfin outside of your local network.
<pre>sudo vi /etc/sysctl.conf</pre>
<pre>net.ipv4.ip_unprivileged_port_start=443 # Put this into the file.</pre>
<pre>sudo sysctl -p # Reload to take effect.</pre>
### Create a dedicated user (not necessary, just my preference).
##### I prefer to have the whole build configured under '/srv', so I create the user without the default home directory and manually set it later.
<pre>sudo useradd -M ctnuser
sudo usermod -aG render,video ctnuser # Add the user to the render and video groups.
sudo mkdir -p /srv/{containers,storage,ctnuser}
sudo mkdir -p /srv/containers/{caddy,jellyfin}
sudo mkdir -p /srv/storage/{downloads,media}
sudo mkdir -p /srv/storage/media/{movies,series}
sudo chown -R ctnuser:ctnuser /srv/ctnuser /srv/containers /srv/storage # Add the ownership to the user.
sudo usermod -d /srv/ctnuser ctnuser # Set the directory as home for the user.</pre>

### Caddyfile configuration for DuckDNS. It is included in the 'caddy' folder. Skip, if you do not plan to reach Jellyfin outside of your local network.
##### I create this with the dedicated user, so it'll have the ownership automatically.
<pre>vi /srv/containers/caddy/Caddyfile</pre>
 <pre> your_domain.duckdns.org {
    reverse_proxy your_internal_IP:8096 
    tls {
    dns duckdns your_token_from_duckdns
    }
  }</pre>

### If you have Dynamic IP, this script will be needed to update your DuckDNS domain. It is included in the 'duckdns' folder. Skip, if you do not plan to reach Jellyfin outside of your local network.
##### I create this with the dedicated user, so it'll have the ownership automatically. Don't forget to make it executable (chmod +x duckdns.sh)
<pre>mkdir /srv/ctnuser/scripts
vi duckdns.sh</pre>
<pre>echo url="https://www.duckdns.org/update?domains=your_domain&token=your_token_from_duckdns&ip=" | curl -k -o /srv/ctnuser/scripts/duck.log -K -</pre>
##### Run the script and it will generate a log file (duck.log), if you set it up good, log will say 'OK', 'NOK' means something is not good.

### Create a crontab entry to run the DuckDNS script every 5 minutes. You can create a systemd service, if that is what you prefer. Skip, if you do not plan to reach Jellyfin outside of your local network.
##### User is not in the sudoers group and doesn't have a password. So in my example, go back to the default user with 'exit'.
<pre>sudo crontab -e</pre>
<pre>*/5 * * * */srv/ctnuser/scripts/duckdns.sh
</pre>

### If you have an external hard drive, you can create a permament mountpoint in the fstab. Careful with this.
##### Use 'fdisk -l' to find the hard drive that you are looking for, for example '/dev/sda1' and use the 'blkid' to match it with the UUID.
<pre>sudo vi /etc/fstab</pre>
<pre>UUID="UUID_of_the_drive" /srv/storage ext4 defaults,noatime 0 2 # A basic mount, modify if you prefer something else.</pre>

### Create the containers, with the container user. Both of these are included in '.sh' format in the 'containers' folder. Caddy is not needed if you do not plan to reach Jellyfin outside of your local network.
##### Caddy is DuckDNS specific, if you use something else, modify accordingly. What you need to keep an eye on, is the ':z' and ':Z'. These for are SELinux. Lowercase means shared, uppercase unshared, very important. If you don't use SELinux it doesn't required.
<pre>podman create --replace \
  --name caddy \
  --publish 443:443/tcp \
  --network host \
  -e TZ=Europe/Budapest \
  --user 0:0 \
  --volume /srv/containers/caddy/Caddyfile:/etc/caddy/Caddyfile:z \
  --volume /srv/containers/caddy/data:/data:Z \
  docker.io/serfriz/caddy-duckdns:latest</pre>
<pre>podman create --replace \
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

### For the last step, if you have SELinux, set up to treat these as regular containers and allow to use the dri_devices for hardware acceleration.
<pre>sudo semanage fcontext -a -e /var/lib/containers /srv/ctnuser/.local/share/containers # This tell SELinux to treat '/srv/ctnuser/.local/share/containers' as '/var/lib/containers', which is the default.
sudo restorecon -R -F/srv/ctnuser/.local/share/containers # This applies the SELinux labels.
sudo setsebool -P container_use_dri_devices 1 # This provides permissions for containers to access and use DRI devices. It is necessary for hardware acceleration.
</pre>

### Now feel free to try it, play with it. Execute the commands with the container user.
<pre>podman start caddy
podman start jellyfin</pre>

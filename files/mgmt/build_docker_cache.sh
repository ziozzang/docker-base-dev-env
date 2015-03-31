#!/bin/bash -x

CONF_DIR=${CONF_DIR:-"/var/www/mgmt-conf"}
NFS_DIR=${NFS_DIR:-"/srv/share"}

# Check Prerequisit.
[ ! -f /usr/bin/docker ] && wget -qO- https://get.docker.com/ | sh
apt-get update && apt-get install -fy apache2 git-core

# Registry Setup.
docker pull registry

# Run Registry & Cache
C=$(docker create --restart always  --name registry-store -p 5000:5000 -v /srv/registry-store/data:/tmp registry)
docker start $C

C=$(docker create --restart always --name registry-cache -p 5050:5000 -v /srv/registry-cache/data:/tmp \
  -e MIRROR_SOURCE=https://registry-1.docker.io -e MIRROR_SOURCE_INDEX=https://index.docker.io \
  -e MIRROR_TAGS_CACHE_TTL=1800 registry)
docker start $C

# Build Configure Share Web Server.
mkdir -p ${CONF_DIR}
cat > /etc/apache2/sites-available/5001-mirror.conf << EOF
Listen 5001
<VirtualHost *:5001>
        DocumentRoot ${CONF_DIR}
        ErrorLog \${APACHE_LOG_DIR}/conf-error.log
        CustomLog \${APACHE_LOG_DIR}/conf-access.log combined
</VirtualHost>

EOF
a2ensite 5001-mirror
service apache2 reload

# Reconfigure Docker itself
echo "DOCKER_OPTS=\"--insecure-registry 127.0.0.1 --registry-mirror http://127.0.0.1:5050 \"" >> /etc/default/docker
service docker restart

while [ -z "$(ifconfig docker0 | grep inet | wc -l)" ] ; do sleep 0.1; done ;
sleep 0.5

# Flannel Build - Newest Version
mkdir -p /var/flannel
cd /var/flannel
git clone https://github.com/coreos/flannel.git

docker run --name flannel-compile \
  -v /var/flannel/flannel:/opt/flannel -i -t google/golang /bin/bash -c "cd /opt/flannel && ./build"
cp -f /var/flannel/flannel/bin/flanneld ${CONF_DIR}
docker rm flannel-compile

# Build NFS Server
mkdir -p ${NFS_DIR}
docker pull cpuguy83/nfs-server
docker create --restart always --name nfs-server --privileged cpuguy83/nfs-server ${NFS_DIR}
docker start nfs-server
NFS_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' nfs-server)

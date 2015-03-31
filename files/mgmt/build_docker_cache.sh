#!/bin/bash

CONF_DIR=${CONF_DIR:-"/var/www/mgmt-conf"}

wget -qO- https://get.docker.com/ | sh

docker pull registry

C=$(docker create --restart always  --name registry-store -p 5000:5000 -v /srv/registry-store/data:/tmp registry)
docker start $C

C=$(docker create --restart always --name registry-cache -p 5050:5000 -v /srv/registry-cache/data:/tmp \
  -e MIRROR_SOURCE=https://registry-1.docker.io -e MIRROR_SOURCE_INDEX=https://index.docker.io \
  -e MIRROR_TAGS_CACHE_TTL=1800 registry)
docker start $C

apt-get install -fy apache2

mkdir -f ${CONF_DIR}

cat > /etc/apache2/sites-available/5001-mirror.conf << EOF
Listen 5001
<VirtualHost *:5001>
        DocumentRoot ${CONF_DIR}
        ErrorLog ${APACHE_LOG_DIR}/conf-error.log
        CustomLog ${APACHE_LOG_DIR}/conf-access.log combined
</VirtualHost>

EOF
a2ensite 5001-mirror

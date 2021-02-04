FROM bitnami/redis:4.0.10
# bitnami/redis執行redis指令移至supervisord中
# bitnami/redis預設USER為1001，要換回root
USER root
###############################################
# bitnami/redis採用的系統是jessie，使用內建的python
# 安裝pip並更新，以及安裝virtualenv供uwsgi用
RUN apt-get update && apt-get -y upgrade
RUN apt-get install -y python-mysqldb
RUN apt-get install -y python-pip
RUN pip install -U pip
RUN pip install --no-cache-dir virtualenv
###############################################
# 直接pip安裝uwsgi會有出錯，需先安裝python2.7-dev
RUN apt-get install -y python2.7-dev
RUN pip install uwsgi

ENV NGINX_VERSION 1.13.12-1~stretch
ENV NJS_VERSION   1.13.12.0.2.0-1~stretch

RUN set -x \
	&& apt-get install --no-install-recommends --no-install-suggests -y gnupg1 apt-transport-https ca-certificates \
	&& \
	NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	apt-get autoremove && rm -rf /var/lib/apt/lists/* \
	&& dpkgArch="$(dpkg --print-architecture)" \
	&& nginxPackages=" \
		nginx=${NGINX_VERSION} \
		nginx-module-xslt=${NGINX_VERSION} \
		nginx-module-geoip=${NGINX_VERSION} \
		nginx-module-image-filter=${NGINX_VERSION} \
		nginx-module-njs=${NJS_VERSION} \
	" \
	&& case "$dpkgArch" in \
		amd64|i386) \
			echo "deb https://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list \
			&& apt-get update \
			;; \
		*) \
			echo "deb-src https://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list \
			\
			&& tempDir="$(mktemp -d)" \
			&& chmod 777 "$tempDir" \
			\
			&& savedAptMark="$(apt-mark showmanual)" \
			\
			&& apt-get update \
			&& apt-get build-dep -y $nginxPackages \
			&& ( \
				cd "$tempDir" \
				&& DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
					apt-get source --compile $nginxPackages \
			) \
			&& apt-mark showmanual | xargs apt-mark auto > /dev/null \
			&& { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
			&& ls -lAFh "$tempDir" \
			&& ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
			&& grep '^Package: ' "$tempDir/Packages" \
			&& echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
			&& apt-get -o Acquire::GzipIndexes=false update \
			;; \
	esac \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						$nginxPackages \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
	&& if [ -n "$tempDir" ]; then \
		apt-get purge -y --auto-remove \
		&& rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
	fi

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log
EXPOSE 80
EXPOSE 443

RUN echo "daemon off;" >> /etc/nginx/nginx.conf
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/
COPY uwsgi.ini /etc/uwsgi/

RUN apt-get update && apt-get install -y supervisor \
&& rm -rf /var/lib/apt/lists/*
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV UWSGI_INI /app/uwsgi.ini

ENV UWSGI_CHEAPER 2

ENV UWSGI_PROCESSES 16

ENV NGINX_MAX_UPLOAD 0

ENV NGINX_WORKER_PROCESSES 1

ENV LISTEN_PORT 80

WORKDIR /app
######################################
# flask安裝與設定
RUN pip install flask
ENV STATIC_URL /static
ENV STATIC_PATH /app/static
ENV STATIC_INDEX 0
ENV PYTHONPATH=/app
################################################
# 節省硬體空間，
RUN apt-get clean autoremove autoclean
################################################
# install requirement
RUN pip install -U pip && \
pip install flask \
flask_cors \
werkzeug \
passlib \
sqlalchemy \
sqlalchemy-migrate \
redis \
line-bot-sdk \
flask_sqlalchemy \
python-dateutil \
flask_wtf \
redis \
apscheduler \
Flask-APScheduler

COPY ./src /app
COPY ./nginx_setting.conf /etc/nginx/conf.d/nginx_setting.conf

CMD ["/usr/bin/supervisord"]
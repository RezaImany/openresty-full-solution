FROM ubuntu:20.04
#Update and install Dependencies
RUN apt update && apt install build-essential zlib1g-dev libpcre3 libpcre3-dev unzip uuid-dev libssl-dev perl make curl wget  -y
# Set versions. Check http://openresty.org for latest version and bundled version of nginx.
ARG OPENRESTY_VERSION=1.21.4.1
ARG NGINX_VERSION=1.21.4
ARG OPENSSL_VERSION=1.1.1n
ARG NPS_VERSION=1.13.35.2-stable
# PSOL library link might be changed, if container build failed for this problem , search the link in google and find new link
ARG PSOL=https://www.modpagespeed.com/release_archive/1.13.35.2/psol-1.13.35.2-x64.tar.gz
ARG PSOL_FILE=psol-1.13.35.2-x64.tar.gz
# ARG NPS_RELEASE_NUMBER=${NPS_VERSION/stable/}
WORKDIR /usr/local/src/

#Get all Build Dependencies and make them ready for building nignx and openresty
ADD  http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz ./
RUN  tar -xzf openresty-${OPENRESTY_VERSION}.tar.gz && rm -rf openresty-${OPENRESTY_VERSION}.tar.gz 
ADD  https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz ./
RUN  tar -xzf openssl-${OPENSSL_VERSION}.tar.gz && rm -f openssl-${OPENSSL_VERSION}.tar.gz 
ADD https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}.zip ./
RUN unzip v${NPS_VERSION}.zip && rm -rf v${NPS_VERSION}.zip
WORKDIR /usr/local/src/incubator-pagespeed-ngx-${NPS_VERSION}
ADD ${PSOL} ./
RUN tar -xzf $PSOL_FILE  && rm -rf $PSOL_FILE
RUN mv /usr/local/src/incubator-pagespeed-ngx-${NPS_VERSION} /usr/local/src/openresty-${OPENRESTY_VERSION}/bundle/nginx-${NGINX_VERSION}/
WORKDIR /usr/local/src/openresty-${OPENRESTY_VERSION}
#Configure Nginx with Optional Modules , You can Add or Remove your Desired Modules but mind the Dependencies
RUN ./configure --with-http_ssl_module \
                        --with-threads \
                        --with-http_secure_link_module \
                        --with-http_sub_module\
                        --with-luajit \
                        --with-openssl=/usr/local/src/openssl-1.1.1n \
                        --with-http_v2_module \
                        --add-module=build//nginx-1.21.4/incubator-pagespeed-ngx-1.13.35.2-stable
RUN make -j8 && make install

#If you want , you can add luarocks and install some packages from it like autossl...
#for this purpose you can uncomment following lines
WORKDIR /usr/local/src/
ADD http://luarocks.org/releases/luarocks-2.0.13.tar.gz ./
RUN tar -xzvf luarocks-2.0.13.tar.gz
WORKDIR /usr/local/src/luarocks-2.0.13/
RUN ./configure --prefix=/usr/local/openresty/luajit \
    --with-lua=/usr/local/openresty/luajit/ \
    --lua-suffix=jit \
    --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1
RUN make -j8 && make install
#in the following line you can see how you can install luarocks package
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-auto-ssl


# forward request and error logs to docker log collector
RUN mkdir -p /var/log/nginx && touch /var/log/nginx/access.log && touch /var/log/nginx/error.log
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d

# Check install.
# RUN /usr/local/openresty/nginx/sbin/nginx -t
# RUN /usr/local/openresty/nginx/sbin/nginx -V



#Introduce Our Entrypoint for Running nginx on Container Startup
COPY ./entrypoint/docker-entrypoint.sh /
COPY ./entrypoint/10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY ./entrypoint/20-envsubst-on-templates.sh /docker-entrypoint.d
COPY ./entrypoint/30-tune-worker-processes.sh /docker-entrypoint.d
ENV PATH=$PATH:/usr/local/openresty/nginx/sbin/
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
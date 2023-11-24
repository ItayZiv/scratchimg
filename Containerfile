FROM docker.io/library/alpine AS build

ARG NGINX_VERSION="1.25.3"
ARG OPENSSL_VERSION="3.0.12"
ARG ZLIB_VERSION="1.3"
ARG PCRE_VERSION="10.42"

RUN apk add --no-cache \
    alpine-sdk \
    findutils \
    gcc \
    libc-dev \
    linux-headers \
    make \
    openssl-dev \
    pcre2-dev \
    zlib-dev \
    && wget -O- https://hg.nginx.org/nginx/archive/release-${NGINX_VERSION}.tar.gz | tar xz \
    && cd nginx-release-${NGINX_VERSION} \
    && wget -O- https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xz \
    && wget -O- https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz | tar xz \
    && wget -O- https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE_VERSION}/pcre2-${PCRE_VERSION}.tar.gz | tar xz \
    && ./auto/configure --with-pcre=./pcre2-${PCRE_VERSION} --with-zlib=zlib-${ZLIB_VERSION} --with-openssl=./openssl-${OPENSSL_VERSION} \
    --builddir=/build --prefix="/nginx" \
    --with-cc-opt="-O2" --with-ld-opt="-s -static" \
    && make

COPY --chown=0:0 /etc /croot/etc
COPY --chown=101:101 nginx.conf /croot/nginx/conf/nginx.conf
COPY --chown=101:101 index.html /croot/www/html/index.html
RUN chmod -R 000 /croot/* \
    && chmod -R u=rwX,go=rX /croot/* \
    && mkdir /croot/nginx/sbin \
    && mv /build/nginx /croot/nginx/sbin/nginx \
    && chown 101:101 /croot/nginx/sbin/nginx \
    && chmod 755 /croot/nginx/sbin/nginx \
    && mkdir /croot/nginx/logs \
    && chown 101:101 /croot/nginx/logs \
    && chmod 775 /croot/nginx/logs

FROM scratch

LABEL org.opencontainers.image.authors="scratchimg@itayziv.dev"

COPY --from=build /croot /

STOPSIGNAL SIGQUIT

USER nginx
EXPOSE 8080

ENTRYPOINT [ "/nginx/sbin/nginx" ]
CMD [ "-g", "daemon off;" ]

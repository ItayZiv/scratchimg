FROM docker.io/library/alpine AS build

ARG NGINX_VERSION="1.25.3"
ARG OPENSSL_VERSION="3.0.12"
ARG ZLIB_VERSION="1.3"
ARG PCRE_VERSION="10.42"


# Install build tools & pgp
RUN apk add --no-cache --virtual .build-deps \
    build-base                               \
    gnupg

# Download OpenSSL source code and verify shasum and GPG signature
RUN cd /build \
    && wget -O- https://www.openssl.org/news/openssl-security.asc | gpg --import                                       \
    && wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz                                       \
    && wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.sha256                                \
    && wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.asc                                   \
    && echo "$(cat openssl-${OPENSSL_VERSION}.tar.gz.sha256 | xargs)  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c - \
    && gpg --verify openssl-${OPENSSL_VERSION}.tar.gz.asc openssl-${OPENSSL_VERSION}.tar.gz                        \
    && tar xf openssl-${OPENSSL_VERSION}.tar.gz                                                                    \
    && rm openssl-${OPENSSL_VERSION}.tar.gz*

# Download zlib source code and verify GPG signature
RUN cd /build                                                                   \
    && wget -O- https://madler.net/madler/pgp.html | gpg --import               \
    && wget https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz                        \
    && wget https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz.asc                    \
    && gpg --verify zlib-${ZLIB_VERSION}.tar.gz.asc zlib-${ZLIB_VERSION}.tar.gz \
    && tar xf zlib-${ZLIB_VERSION}.tar.gz                                       \
    && rm zlib-${ZLIB_VERSION}.tar.gz*

# Download PCRE source code and verify GPG signature
RUN cd /build                                                                                                              \
    && wget -O- https://github.com/PhilipHazel.gpg | gpg --import                                                          \
    && wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE_VERSION}/pcre2-${PCRE_VERSION}.tar.gz     \
    && wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE_VERSION}/pcre2-${PCRE_VERSION}.tar.gz.sig \
    && gpg --verify pcre2-${PCRE_VERSION}.tar.gz.sig pcre2-${PCRE_VERSION}.tar.gz                                          \
    && tar xf pcre2-${PCRE_VERSION}.tar.gz                                                                                 \
    && rm pcre2-${PCRE_VERSION}.tar.gz*

# Download Nginx source code and verify GPG signature
RUN mkdir /build && cd /build                                                       \
    && wget -O- https://nginx.org/keys/thresh.key | gpg --import                   \
    && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz                 \
    && wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc             \
    && gpg --verify nginx-${NGINX_VERSION}.tar.gz.asc nginx-${NGINX_VERSION}.tar.gz \
    && tar xf nginx-${NGINX_VERSION}.tar.gz                                         \
    && rm nginx-${NGINX_VERSION}.tar.gz*

# Build NGINX
RUN cd /build/nginx-${NGINX_VERSION} \
    && ./configure --with-pcre=../pcre2-${PCRE_VERSION} --with-zlib=../zlib-${ZLIB_VERSION} --with-openssl=../openssl-${OPENSSL_VERSION} \
    --builddir=/dist --prefix="/nginx" \
    --with-cc-opt="-O2" --with-ld-opt="-s -static" \
    && make

FROM docker.io/library/alpine AS croot

COPY --chown=0:0 /etc /croot/etc
COPY --chown=101:101 nginx.conf /croot/nginx/conf/nginx.conf
COPY --chown=101:101 index.html /croot/www/html/index.html
COPY --from=build /dist/nginx /croot/nginx/sbin/nginx
RUN chmod -R 000 /croot/* \
    && chmod -R u=rwX,go=rX /croot/* \
    && chown 101:101 /croot/nginx/sbin/nginx \
    && chmod 755 /croot/nginx/sbin/nginx \
    && mkdir /croot/nginx/logs \
    && chown 101:101 /croot/nginx/logs \
    && chmod 775 /croot/nginx/logs

FROM scratch

LABEL org.opencontainers.image.authors="scratchimg@itayziv.dev"

COPY --from=croot /croot /

STOPSIGNAL SIGQUIT

USER nginx
EXPOSE 8080

ENTRYPOINT [ "/nginx/sbin/nginx" ]
CMD [ "-g", "daemon off;" ]

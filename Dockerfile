FROM python:3-alpine

LABEL maintainer="WebitDesign GbR <development@webitdesign.de>"

RUN apk add --no-cache --virtual .build-deps linux-headers gcc musl-dev \
                                 libffi-dev openssl-dev dialog tini \
  && pip install setuptools wheel ruamel.yaml certbot --no-cache-dir \
  && apk del .build-deps \
  && mkdir /scripts

COPY crontab /etc/crontabs
COPY ./scripts/ /scripts

RUN crontab /etc/crontabs/crontab \
    && chmod +x /scripts/ -R \
    && ln -s /scripts/getcerts.py /usr/bin/issue \
    && ln -s /scripts/getcerts.py /usr/bin/renew

VOLUME /certs
VOLUME /etc/letsencrypt
EXPOSE 80 443

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/scripts/startup.sh"]


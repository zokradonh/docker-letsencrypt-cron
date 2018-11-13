FROM python:3-alpine

LABEL maintainer="WebitDesign GbR <development@webitdesign.de>"

RUN apk add --no-cache --virtual .build-deps linux-headers gcc musl-dev \
  && apk add --no-cache libffi-dev openssl-dev dialog tini \
  && pip install setuptools wheel ruamel.yaml certbot --no-cache-dir \
  && apk del .build-deps

COPY crontab /etc/crontabs
COPY ./scripts/ /scripts

RUN crontab /etc/crontabs/crontab \
    && chmod +x /scripts/ -R \
    && ln -s /scripts/getcerts.py /usr/bin/issue \
    && ln -s /scripts/getcerts.py /usr/bin/renew

EXPOSE 80 443

ENTRYPOINT ["/sbin/tini", "-e", "143", "--"]
CMD ["crond", "-f"]

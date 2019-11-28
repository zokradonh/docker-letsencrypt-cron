FROM python:3-alpine

LABEL maintainer="WebitDesign GbR <development@webitdesign.de>"

RUN apk add --no-cache --virtual .build-deps linux-headers gcc musl-dev \
  && apk add --no-cache libffi-dev openssl-dev dialog tini curl jq \
  && pip install setuptools wheel ruamel.yaml certbot requests --no-cache-dir \
  && apk del .build-deps

COPY crontab /etc/crontabs
COPY ./scripts/ /scripts

RUN curl -s -S -o /scripts/acme-dns-auth.py https://raw.githubusercontent.com/joohoi/acme-dns-certbot-joohoi/master/acme-dns-auth.py \
    && chmod 0700 /scripts/acme-dns-auth.py \
    && sed -i "s/ACMEDNS_URL\s*=.*/ACMEDNS_URL = os.environ.get\(\"ACMEDNSAUTH_URL\", None\)/" /scripts/acme-dns-auth.py \
    && crontab /etc/crontabs/crontab \  
    && chmod +x /scripts/ -R \
    && ln -s /scripts/getcerts.py /usr/bin/issue \
    && ln -s /scripts/getcerts.py /usr/bin/renew

EXPOSE 80 443

ENTRYPOINT ["/sbin/tini", "-e", "143", "--"]
CMD ["crond", "-f"]

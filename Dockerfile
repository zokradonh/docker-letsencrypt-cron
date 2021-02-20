FROM python:3-alpine as builder

COPY requirements.txt /build/requirements.txt

RUN apk add --no-cache \
  linux-headers \
  gcc \
  musl-dev \
  cargo \
  libffi-dev \
  openssl-dev \
  && pip wheel -r /build/requirements.txt --wheel-dir=/build/wheels

FROM python:3-alpine

RUN apk add --no-cache libffi-dev openssl-dev dialog tini curl jq

COPY --from=builder /build /build

RUN pip install --no-index --find-links=/build/wheels -r /build/requirements.txt

COPY crontab /etc/crontabs
COPY ./scripts/ /scripts
COPY README.md /build/README.md

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

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.vendor=ZokRadonh \
      org.label-schema.license=MIT \
      org.label-schema.description="Let's Encrypt Certbot Docker Image" \
      org.label-schema.vcs-url="https://github.com/zokradonh/docker-letsencrypt-cron" \
      org.label-schema.usage="/build/README.md"

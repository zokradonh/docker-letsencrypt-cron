# Code origin
This repository is based on a fork from https://github.com/henridwyer/docker-letsencrypt-cron, but has changed significantly since then.

# docker-letsencrypt-cron
Create and automatically renew website SSL certificates using the letsencrypt free certificate authority, and its client *certbot*.

This image will renew your certificates on startup and every full hour, and place the lastest ones in the /certs folder in the container.

# Usage

## Config-file
Configurations have to be saved or mounted as `/le/certs.yml` or `/le/certs.yaml` (`.yml` has a higher priority). Root elements will be the name of your certs.

Field | Meaning | Default | Mandatory
--- | --- | --- | ---
args | Addition args to pass to certbot (as a string) | _None_ | no
challenges | Prefered challenges | http | no
debug | print debug-statements | false | no
disabled | do not try to issue a certificate and ignore this entry | false | no
domains | List of domains included in the cert as a yaml-list | _None_ | yes
dry_run | Do not issue an actual cert | false | no
email | Let's Encrypt account mail | _None_ | yes
staging | Obtain a staging cert. Ignored if used with `dry_run` | false | no
webroot | Path to webroot. If this is set webroot mode is used instead of standalone | _None_ | no

Example:
```yaml
example.com:
  domains:
    - example.com
    - example.org
  dry_run: true
  debug: true
  challenges: 'http'
  email: 'test@example.org'
mycert:
  domains:
    - test.example.com
  dry_run: true
  webroot: '/webroot'
  email: 'test@example.org'
  staging: true
wildcard:
  domains:
    - *.example.com
  challenges: 'dns' # currently unsupported
  dry_run: true
min:
  domains:
    - min.example.com
  email: test@example.com
```
The issued certificates will be named 'example.com', 'mycert' and 'wildcard'

## Running

Running the image with _issue_ or _renew_ (both do the same) as command, the container will try to obtain an certificate immediately. Otherwise the command just gets executed.

### Using the automated image

```shell
docker run --name certbot -v /YOUR/CERT/DIR:/certs -v/CONF/DIR/certs.yml:/le/certs.yml --restart always webitdesign/docker-letsencrypt-cron
```

### Building the image

The easiest way to build the image yourself is to use the provided docker-compose file.

```shell
docker-compose up -d
```

You may want to run the certificate generation script immediately after changing `certs.yml`:

```shell
docker exec certbot issue
```

### docker-compose
Example docker-compose.yml:
```yaml
version: '3.3'
services:
  letsencrypt: webitdesign/letsencrypt-cron
    container_name: letsencrypt
    volumes:
      - ./certs:/certs
      - ./cert-config.yml:/le/certs.yml
    ports:
      - '80:80'
    restart: always
```

## Obtained certificates
`{cert}` is a placeholder for the certificates names.

File | Content
--- | ---
{cert}.cert.pem | Certificate solely
{cert}.chain.pem | Validation chain
{cert}.fullchain.pem | Certificate and validation chain
{cert}.key.pem | Private key
{cert}.concat.pem | fullchain and key combined

# ACME Validation challenge

To authenticate the certificates, the you need to pass the ACME validation challenge. This requires requests made on port 80 to your.domain.com/.well-known/ to be forwarded to this container.

The recommended way to use this image is to set up your reverse proxy to automatically forward requests for the ACME validation challenges to this container.

## Haproxy example

If you use a haproxy reverse proxy, you can add the following to your configuration file in order to pass the ACME challenge.

``` haproxy
frontend http
  bind *:80
  acl letsencrypt_check path_beg /.well-known

  use_backend certbot if letsencrypt_check

backend certbot
  server certbot certbot:80 maxconn 32
```

## Nginx example

If you use nginx as a reverse proxy, you can add the following to your configuration file in order to pass the ACME challenge.

``` nginx
upstream certbot_upstream{
  server certbot:80;
}

server {
  listen              80;
  location '/.well-known/acme-challenge' {
    default_type "text/plain";
    proxy_pass http://certbot_upstream;
  }
}

```

## Apache example
In the following example `$container` is the name of your letsencrypt-container, e.g. _letsencrypt_.

``` apache
  ProxyPreserveHost On
  ProxyPass "/.well-known/" "http://$container/.well-known/"
  ProxyPassReverse "/.well-known/" "http://$container/.well-known/"
```

# More information

Find out more about letsencrypt: https://letsencrypt.org

Certbot github: https://github.com/certbot/certbot

# Changelog
### 0.5
- Added tini for clean container handling
- Simplified `issue` and `renew` commands
- Crontab calling nonexistent file

### 0.4
- Rewrite
- Use config-file instead of environment-variables
- Renew every hour
- Do not force renewal
- Use python:3-alpine image instead of python:2-alpine

### 0.3
- Add support for webroot mode.
- Run certbot once with all domains.

### 0.2
- Upgraded to use certbot client
- Changed image to use alpine linux

### 0.1
- Initial release

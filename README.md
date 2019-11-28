# Code origin
This repository is a fork from https://github.com/webitdesign/docker-letsencrypt-cron based on a fork from https://github.com/henridwyer/docker-letsencrypt-cron, but has changed significantly since then.

# docker-letsencrypt-cron
Create and automatically renew website SSL certificates using the letsencrypt free certificate authority, and its client *certbot*.

This image will renew your certificates on startup and every full hour, and place the lastest ones in the /certs folder in the
container.

# Usage

## Config-file
Configurations have to be saved or mounted as `/le/certs.yml` or `/le/certs.yaml` (`.yml` has a higher priority). Root elements
will be the name of your certs.

Field | Meaning | Default | Mandatory
--- | --- | --- | ---
args | Addition args to pass to certbot (as a string) | _None_ | no
challenges | Prefered challenges | http | no
debug | print debug-statements | false | no
disabled | do not try to issue a certificate and ignore this entry | false | no
domains | List of domains included in the cert as a yaml-list | _None_ | yes
dry_run | Do not issue an actual cert | false | no
email | Let's Encrypt account mail | _None_ | yes
acmednsurl | URL of the [acme-dns](https://github.com/joohoi/acme-dns) auth server for DNS-01 challenge | https://auth.acme-dns.io | no
staging | Obtain a staging cert. Ignored if used with `dry_run` | false | no
webroot | Path to webroot. If this is set webroot mode is used instead of standalone | _None_ | no
reload_after_renew | List of Docker API calls (in fact any HTTP call is possible) to be made after renewal (e.g. restart Apache-Container) | _None_ | no


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
  reload_after_renew: 
    - http://dockerproxy:2751/containers/THE_REMOTE_CONTAINER_ID_OR_NAME/kill?signal=SIGHUP
wildcard:
  domains:
    - *.example.com
  challenges: 'dns'
  acmednsurl: https://auth.acme-dns.io
  dry_run: true
min:
  domains:
    - min.example.com
  email: test@example.com
```
The issued certificates will be named 'example.com', 'mycert' and 'wildcard'

## Reload feature (reload_after_renew)

In order to use this feature another container is needed (https://github.com/tecnativa/docker-socket-proxy). Be careful with this
container since it has access to `/var/run/docker.sock`. Containers with access to `/var/run/docker.sock` have effectively access
to your full host system.

## Running

Running the image with _issue_ or _renew_ (both do the same) as command, the container will try to obtain a certificate 
immediately. Otherwise the command just gets executed.

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
  letsencrypt: zokradonh/letsencrypt-cron
    container_name: letsencrypt
    volumes:
      - ./data:/etc/letsencrypt
      - ./cert-config.yml:/le/certs.yml
    ports:
      - '80:80'
    restart: always
  
  dockerproxy: tecnativa/docker-socket-proxy
    container_name: docker-proxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./cert-config.yml:/le/certs.yml
    environment:
      - POST=1 # allow HTTP-POST API calls (e.g. container stop/kill/restart)
      - ALLOW_RELOADS=/le/certs.yml

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

# ACME HTTP-01 Validation challenge

To authenticate the certificates, the you need to pass the ACME validation challenge. This requires requests made on port 80 to
 your.domain.com/.well-known/ to be forwarded to this container.

The recommended way to use this image is to set up your reverse proxy to automatically forward requests for the ACME validation 
challenges to this container.

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

# ACME DNS-01 Validation challenge

In order to get wildcard certificates you need to comply the DNS-01 validation. To understand this validation you need to know some facts:
- Let's Encrypt tries to validate `_acme-challenge.<YOUR_DOMAIN>`
- You can create a CNAME record to redirect this record to a nameserver easier to control (e.g. your domain provider does not provide any API for DNS zone manipulation)
- This docker image refers to [acme-dns](https://github.com/joohoi/acme-dns) as nameserver software that is easier to control
  - You can either start your own container (recommended) with acme-dns (set `acmednsurl` config in this case) or use the nameserver/acme-dns-instance of the author of acme-dns(default setting). If you use the default setting the author of acme-dns could request certificates of your domains.
- If you host acme-dns in your own container please also check [acme-dns documentation](https://github.com/joohoi/acme-dns#self-hosted).

## How to create the CNAME record?
The CNAME record should not simply redirect to the nameserver but should redirect to a specific subdomain generated by acme-dns. This subdomain is generated on the first request try. Due to the complex nature of this interaction you have to follow the following procedure:
- Edit your config.yml by adding `challenges: 'dns'` and `acmednsurl` if needed to one entry
- Start your container `letsencrypt-cron` if not already running (config change does not require restart)
- Trigger certificate renew with the following extra parameter: `docker exec -it <CONTAINER-NAME> renew initial`
- The scripts fails because the CNAME record is missing. In the error message it tells you what should be in the CNAME record.
- Create the CNAME record according to the information given by the error message.
- Reexecute the command `docker exec -it <CONTAINER-NAME> renew initial` after some minutes waiting (to be sure the DNS records are correctly written)
- Now the script tries the DNS-01 challenge and should succeed this time

# More information

Find out more about Let's Encrypt: https://letsencrypt.org

Certbot github: https://github.com/certbot/certbot

acme-dns: https://github.com/joohoi/acme-dns

docker-api-proxy: https://github.com/Tecnativa/docker-socket-proxy

# Changelog
### 0.7
- Added DNS-01 challenge implementation [acme-dns](https://github.com/joohoi/acme-dns)

### 0.6
- Added feature to reload/restart other containers after renewal

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

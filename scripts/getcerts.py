#!/usr/bin/env python3

from pathlib import Path
from ruamel.yaml import YAML
from subprocess import call
from shlex import quote
import os
import sys
import requests
import os
import sys

class ConfigurationException(Exception):
    pass

def make_requests():
    # get path
    path = Path('/le/certs.yml')
    if not path.is_file():
        fallback_path = Path('/le/certs.yaml')
        if not fallback_path.is_file():
            raise ConfigurationException('certs-configuration not found')
        path = fallback_path

    # read config
    config = YAML().load(path)

    # build params
    param_list = []
    for cert in config:
        if 'disabled' in config[cert] and config[cert]['disabled']:
            print('Ignoring {cert}'.format(cert=cert))
            continue

        debug = False

        # Set general parameters
        params = ("certonly -n --agree-tos"
            +" --renew-with-new-domains" # renew if domain-list changed
            +" --keep-until-expiring"   # otherwise keep until it expires
            +" --cert-name "+cert
            +" --deploy-hook /scripts/renewal-hook.sh"
        )

        # Set E-Mail
        if not 'email' in config[cert]:
            print("Missing email for {cert}".format(cert=cert))
            continue
        params += ' --email '+config[cert]['email']

        # Set Domain
        if not 'domains' in config[cert]:
            print("No domains for {cert}".format(cert=cert))
            continue
        for d in config[cert]['domains']:
            params += ' -d '+quote(d)

        # Set Challenge
        params += ' --preferred-challenges '
        if 'challenges' in config[cert]:
            params += config[cert]['challenges']
        else:
            params += 'http'
        
        # Debug option
        if 'debug' in config[cert] and config[cert]['debug']:
            params += ' --debug'
            debug = True

        # ECDSA key type option
        if 'ecdsa' in config[cert] and config[cert]['ecdsa']:
            params += ' --key-type ecdsa'

        # Dry Run option
        if 'dry_run' in config[cert] and config[cert]['dry_run']:
            params += ' --dry-run'
            print("-------------dRY")
        else:
            endpoint = "https://acme-v02.api.letsencrypt.org/directory"
            if 'staging' in config[cert] and config[cert]['staging']:
                print('------------stage')
                params += ' --staging'
                endpoint = "https://acme-staging-v02.api.letsencrypt.org/directory"
            params += ' --server '+endpoint

        if 'challenges' in config[cert] and config[cert]['challenges'] == "dns":
            # DNS-01 challenge
            if not 'acmednsurl' in config[cert]:
                os.environ['ACMEDNSAUTH_URL'] = "https://auth.acme-dns.io"
            else:
                os.environ['ACMEDNSAUTH_URL'] = config[cert]['acmednsurl']
            params += ' --manual --manual-public-ip-logging-ok'
            params += ' --manual-auth-hook /scripts/acme-dns-auth.py'
            if len(sys.argv) > 1 and sys.argv[1] == "initial":
                params += ' --debug-challenges'
        else:
            # HTTP-01 challenge via webroot or standalone
            if 'webroot' in config[cert] and config[cert]['webroot']:
                params += ' --webroot -w '+config[cert]['webroot']
            else:
                params += ' --standalone'

        # Additional custom args
        if 'args' in config[cert]:
            params += ' '+config[cert]['args']

        if debug:
            print('Cerbot-args for {cert}: {params}'.format(cert=cert, params=params))

        try:
            # Request certificate
            call('certbot {params}'.format(params=params), shell=True)

            # Run renew handler if there is a new certificate (and if there is a handler)
            isRenewed = Path('/etc/letsencrypt/live/{certname}/new.event'.format(certname=cert))
            if isRenewed.is_file():
                isRenewed.unlink()
                if 'reload_after_renew' in config[cert]:
                    for callurl in config[cert]['reload_after_renew']:
                        r = requests.post(callurl)
            
        finally:
            pass

if __name__ == '__main__':
    try:
        make_requests()
    except Exception as e:
        print("Error: "+str(e))
    pass

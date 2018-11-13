#!/usr/bin/env python3

from pathlib import Path
from ruamel.yaml import YAML
from subprocess import call

class ConfigurationException(Exception):
    pass

def read_domain_config():
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
        params = ("certonly -n --agree-tos"
            +" --renew-with-new-domains" # renew if domain-list changed
            +" --keep-until-expiring"   # otherwise keep until it expires
            +" --cert-name "+cert
            +" --deploy-hook /scripts/renewal-hook.sh"
        )

        if not 'email' in config[cert]:
            print("Missing email for {cert}".format(cert=cert))
            continue
        params += ' --email '+config[cert]['email']

        if not 'domains' in config[cert]:
            print("No domains for {cert}".format(cert=cert))
            continue
        for d in config[cert]['domains']:
            params += ' -d '+d

        params += ' --preferred-challenges '
        if 'challenges' in config[cert]:
            params += config[cert]['challenges']
        else:
            params += 'http'

        if 'debug' in config[cert] and config[cert]['debug']:
            params += ' --debug'
            debug = True

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

        if 'webroot' in config[cert] and config[cert]['webroot']:
            params += ' --webroot -w '+config[cert]['webroot']
        else:
            params += ' --standalone'

        if 'args' in config[cert]:
            params += ' '+conf[cert]['args']

        if debug:
            print('Cerbot-args for {cert}: {params}'.format(cert=cert, params=params))

        param_list.append(params)

    return param_list

def get_cert(params):
    try:
        call('certbot {params}'.format(params=params), shell=True)
    finally:
        pass

if __name__ == '__main__':
    try:
        param_list = read_domain_config()
        for p in param_list:
            get_cert(p)

    except Exception as e:
        print("Error: "+str(e))
    pass

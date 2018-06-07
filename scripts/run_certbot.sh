certname=$1
shift

echo "Running certbot for cert $certname"
certbot $@
ec=$?
echo "certbot exit code $ec"
if [ $ec -eq 0 ]; then
  # concat the full chain with the private key (e.g. for haproxy)
  cat /etc/letsencrypt/live/$certname/fullchain.pem /etc/letsencrypt/live/$certname/privkey.pem > /certs/$certname.concat.pem

  # keep full chain and private key in separate files (e.g. for nginx and apache)
  cp /etc/letsencrypt/live/$certname/fullchain.pem /certs/$certname.fullchain.pem
  cp /etc/letsencrypt/live/$certname/privkey.pem /certs/$certname.key.pem

  # seperate cert and chain e.g. for openldap and older apache/nginx-versions
  cp /etc/letsencrypt/live/$certname/cert.pem /certs/$certname.cert.pem
  cp /etc/letsencrypt/live/$certname/chain.pem /certs/$certname.chain.pem
  echo "Certificate $certname obtained! Your new certificate is in /certs"
else
  echo "Cerbot failed for $certname. Check the logs for details."
fi

exit $ec

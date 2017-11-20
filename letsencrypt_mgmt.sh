#!/bin/sh 
# USE CERTBOT TO REQUEST NEW CERTIFICATES
# AND COPY THEM INTO NGINX SSL DIR
# NGINX RESTART IS NEW CERTIF RETRIEVED

# VARS
SITES="deluge nextcloud"          # CURRENT WEBSITES
DOMAIN_NAME="othalland.xyz"       # MY DOMAIN NAME
WR_PATH="/tmp/letsencrypt-auto"
NGX_BIN="/usr/local/etc/rc.d/nginx"
MD5_BIN="/sbin/md5"
CERTBOT_BIN="/usr/local/bin/certbot"
LETSENCRYPT_CFG_DIR="/usr/local/etc/letsencrypt/live"
NGX_SSL_DIR="/usr/local/etc/nginx/ssl"
CERT_FILES="cert.pem chain.pem fullchain.pem privkey.pem"
NGX_RELOAD_NEEDED=0

newCerts() {
  SITE="$1"
  FQDN="$SITE.$DOMAIN_NAME"
  CFG_DIR="$LETSENCRYPT_CFG_DIR/$FQDN/"
  $CERTBOT_BIN certonly --config-dir $CFG_DIR --webroot --webroot-path $WR_PATH -d $DOMAIN_NAME -d $FQDN || {
    echo "Failed to request new certificates for $SITE"
    return 1
  }
}

renewCerts() {
  SITE="$1"
  $CERTBOT_BIN renew --config-dir $LETSENCRYPT_CFG_DIR/$SITE.$DOMAIN_NAME || {
    echo "Failed to renew current certificates"
    return 1
  }
}

copyCerts() {
  SITE="$1"
  LE_NEW_CERT_DIR="$LETSENCRYPT_CFG_DIR/$SITE.$DOMAIN_NAME/live/$DOMAIN_NAME"
  NGX_SSL_SITE_DIR="$NGX_SSL_DIR/$SITE.$DOMAIN_NAME"
  if [ ! -d "$NGX_SSL_SITE_DIR" ]; then
    mkdir -p $NGX_SSL_SITE_DIR || {
      echo "Failed to create $NGX_SSL_SITE_DIR"
      return 1
    }
  fi
  for CERT_FILE in $CERT_FILES
  do
    LE_CERT_FILE="$LE_NEW_CERT_DIR/$CERT_FILE"
    NGX_SSL_CERT_FILE="$NGX_SSL_DIR/$SITE.$DOMAIN_NAME/$CERT_FILE"
    if [ "$($MD5_BIN -q $LE_CERT_FILE)" != "$($MD5_BIN -q $NGX_SSL_CERT_FILE)" ]; then
      echo "Copying new certificates for $SITE"
      cp $LE_CERT_FILE $NGX_SSL_CERT_FILE || {
        echo "Failed to copy $file"
        return 1
      }
    fi
  done
}

ngx_reload() {
  $NGX_BIN reload || {
    echo "Failed to reload nginx"
    return 1
  }
}

renew() {
  if [ "$#" != "1" ]; then
    echo "renew must be called with 1 param"
    return 1
  fi
  SITE="$1"
  renewCerts $SITE || return 1
  copyCerts $SITE || return 1
}

newCertsAndInstall() {
  if [ "$#" != "1" ]; then
    echo "new must be called with 1 param"
    return 1
  fi
  SITE="$1"
  newCerts $SITE || return 1
  copyCerts $SITE || return 1
  ngx_reload || return 1
}

certsRenewAndInstall() {
  NGX_NEED_RELOAD=0
  for site in $SITES
  do
    renew $site || {
      echo "Failed to renew and install new certs fir $site"
      return 1
    }
    NGX_NEED_RELOAD=1
  done
  if [ "$NGX_NEED_RELOAD" == "1" ]; then
    ngx_reload || return 1
  fi
}

case $1 in
  new)
    newCertsAndInstall $2 || exit 1
    ;;
  renew)
    certsRenewAndInstall || exit 1
    ;;
  *)
    echo "Usage :"
    echo "- $0 new newshortname"
    echo "- $0 renew"
    exit 1
    ;;
esac

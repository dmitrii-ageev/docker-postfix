#!/bin/sh

# Domain name can be passes as the first argument to this script
if [ ! -z "$1" ]; then
  DOMAINNAME="$1"

  # Hostname can be passed as the second argumanet to this script
  if [ ! -z "$2" ]; then
    SERVERNAME="$2"
  else
    SERVERNAME="mail.${DOMAINNAME}"
  fi

  MY_DESTINATION="localhost, localhost.localdomain, ${SERVERNAME}, ${DOMAINNAME}"
  
  echo ${SERVERNAME} > /etc/hostname
  echo ${SERVERNAME} > /etc/mailname
  
  postconf -e myhostname="${SERVERNAME}"
  postconf -e mydestination="${MY_DESTINATION}"
  postconf -e smtpd_banner="${SERVERNAME} ESMTP"
fi
 
/usr/lib/postfix/master &
rsyslogd -n

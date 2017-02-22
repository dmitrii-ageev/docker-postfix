FROM ubuntu:14.04
MAINTAINER Dmitrii Ageev <d.ageev@gmail.com>

# Declare variables
ENV ROOT_ALIAS d.ageev@gmail.com
ENV DOMAINNAME example.com
ENV MAILNAME mail.${DOMAINNAME}
ENV MY_NETWORKS 172.16.0.0/12 127.0.0.0/8
ENV MY_DESTINATION localhost.localdomain, localhost, ${DOMAINNAME}
ENV DKIM_SELECTOR default

# Install Postfix
RUN echo ${MAILNAME} > /etc/hostname; \
    echo ${MAILNAME} > /etc/mailname; \
    echo "postfix postfix/main_mailer_type string Internet site" > preseed.txt; \
    echo "postfix postfix/mailname string ${MAILNAME}" >> preseed.txt

## Load pre config for apt
RUN debconf-set-selections preseed.txt

## Install
RUN apt-get -q update; \
    apt-get -y --force-yes install \
    postfix \
    opendkim \
    mailutils \
    opendkim-tools \
    sasl2-bin

## Generate certificates to be used for TLS encryption and/or certificate Authentication
RUN touch smtpd.key; \
    chmod 600 smtpd.key; \
    openssl genrsa 1024 > smtpd.key; \
    openssl req -new -key smtpd.key -x509 -days 3650 -out smtpd.crt; \
    openssl req -new -x509 -extensions v3_ca -keyout cakey.pem -out cacert.pem -days 3650; \
    sudo mv smtpd.key /etc/ssl/private/; \
    sudo mv smtpd.crt /etc/ssl/certs/; \
    sudo mv cakey.pem /etc/ssl/private/; \
    sudo mv cacert.pem /etc/ssl/certs/

# Configure Postfix
## Add the root alias to /etc/aliases
RUN echo "root: ${ROOT_ALIAS}" >> /etc/postfix/aliases; \
    newaliases

RUN postconf -e smtpd_banner="${MAILNAME} ESMTP"; \
    postconf -e mail_spool_directory="/var/spool/mail/"; \
    postconf -e mailbox_command=""; \
    postconf -e smtpd_sasl_auth_enable="yes"; \
    postconf -e smtpd_sasl_security_options="noanonymous"; \
    postconf -e broken_sasl_auth_clients="yes"; \
    postconf -e smtp_tls_security_level="may"; \
    postconf -e smtpd_recipient_restrictions="permit_mynetworks permit_sasl_authenticated reject_unauth_destination"; \
    postconf -e smtpd_helo_restrictions="permit_sasl_authenticated, permit_mynetworks, reject_invalid_hostname, reject_unauth_pipelining, reject_non_fqdn_hostname"; \
    postconf -e inet_interfaces="all"; \
    postconf -e myhostname="${MAILNAME}"; \
    postconf -e mydestination="${MY_DESTINATION}"; \
    postconf -e milter_default_action="accept"; \
    postconf -e milter_protocol="2"; \
    postconf -e smtpd_milters="inet:localhost:8891"; \
    postconf -e non_smtpd_milters="inet:localhost:8891"

## Add user postfix to sasl group
RUN gpasswd -a postfix sasl

## Configure Sasl2
RUN sed -i 's/^START=.*/START=yes/g' /etc/default/saslauthd; \
    sed -i 's/^MECHANISMS=.*/MECHANISMS="shadow"/g' /etc/default/saslauthd

RUN echo "pwcheck_method: saslauthd" > /etc/postfix/sasl/smtpd.conf; \
    echo "mech_list: plain login" >> /etc/postfix/sasl/smtpd.conf; \
    echo "saslauthd_path: /var/run/saslauthd/mux" >> /etc/postfix/sasl/smtpd.conf

## Chroot saslauthd fix
RUN sed -i 's/^OPTIONS=/#OPTIONS=/g' /etc/default/saslauthd; \
    echo 'OPTIONS="-c -m /var/spool/mail/var/run/saslauthd"' >> /etc/default/saslauthd

## DKIM settings
RUN mkdir -p /etc/postfix/dkim
RUN echo "InternalHosts	   172.17.0.1" >> /etc/opendkim.conf; \
    echo "KeyFile          /etc/postfix/dkim/dkim.key" >> /etc/opendkim.conf; \
    echo "Selector         mail" >> /etc/opendkim.conf; \
    echo "SOCKET           inet:8891@localhost" >> /etc/opendkim.conf; \
    echo "Domain           ${DOMAINNAME}" >> /etc/opendkim.conf; \
    echo "Canonicalization simple" >> /etc/opendkim.conf

RUN sed -i 's/^SOCKET=/#SOCKET=/g' /etc/default/opendkim; \
    echo 'SOCKET="inet:8891@localhost"' >> /etc/default/opendkim

RUN opendkim-genkey -s $DKIM_SELECTOR -d ${DOMAINNAME}; \
    mv $DKIM_SELECTOR.private /etc/postfix/dkim/dkim.key; \
    echo ">> printing out public dkim key:"
    cat $DKIM_SELECTOR.txt
    mv $DKIM_SELECTOR.txt /etc/postfix/dkim/dkim.public
    echo ">> please at this key to your DNS System"
  fi
  echo ">> change user and group of /etc/postfix/dkim/dkim.key to opendkim"
  chown -R opendkim:opendkim /etc/postfix/dkim/
  chmod -R o-rwX /etc/postfix/dkim/
  chmod o=- /etc/postfix/dkim/dkim.key
fi



# We disable IPv6 for now, IPv6 is available in Docker even if the host does not have IPv6 connectivity.

# Postfix ports
## TCP:25  - SMPT
## TCP:465 - SMTPS
## TCP:587 - Mail Submission
EXPOSE 25/tcp 465/tcp 587/tcp

VOLUME /var/log/postfix
VOLUME /var/spool/mail

ENTRYPOINT ["/opt/startup.sh"]
CMD ["-h"]


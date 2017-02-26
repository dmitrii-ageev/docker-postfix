#FROM ubuntu:14.04
FROM debian:stable-slim
LABEL maintainer "Dmitrii Ageev <d.ageev@gmail.com>"

# Declare variables
## You can specify the DOMAINNAME and SERVERNAME during container build time with the --build-arg option
ARG DOMAINNAME="example.com"
ARG SERVERNAME="mail.${DOMAINNAME}"
## Localhost and Docker networks only
ENV MY_NETWORKS "127.0.0.0/8, 172.17.0.0/16, [::1]/128, [fe80::]/64"
ENV MY_DESTINATION "localhost, localhost.localdomain, ${SERVERNAME}, ${DOMAINNAME}"

# Install Postfix
# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND noninteractive

## Install
RUN apt-get -q update; \
    apt-get -y --force-yes install \
    rsyslog \
    postfix 

# Configure Postfix
ADD files/aliases /etc/aliases
RUN newaliases

RUN postconf -e myhostname="${SERVERNAME}"; \
    postconf -e mydestination="${MY_DESTINATION}"; \
    postconf -e inet_interfaces="all"; \
    postconf -e mail_spool_directory="/var/mail/"; \
    postconf -e mailbox_command=""; \
    postconf -e disable_dns_lookups="no"; \
    postconf -e smtp_dns_support_level="enabled"; \
    postconf -e smtp_host_lookup="dns"; \
    postconf -e smtpd_banner="${SERVERNAME} ESMTP"; \
    postconf -e alias_database="hash:/etc/aliases"; \
    postconf -e alias_maps="hash:/etc/aliases"; \
# Don't talk to mail systems that don't know their own hostname or have an invalid hostname.
    postconf -e smtpd_helo_required="yes"; \
    postconf -e smtpd_helo_restrictions="permit_sasl_authenticated, permit_mynetworks, reject_invalid_hostname, reject_unauth_pipelining, reject_non_fqdn_hostname"; \
# Don't accept mail from domains that don't exist.
    postconf -e smtpd_sender_restrictions="reject_unknown_sender_domain"; \
# Relay control: local clients and authenticated clients may specify any destination domain.
    postconf -e smtpd_relay_restrictions="permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"; \
# Spam control: exclude local clients and authenticated clients from DNSBL lookups.
    postconf -e smtpd_recipient_restrictions="permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"; \
    postconf -e maps_rbl_domains="cbl.abuseat.org, bl.spamcop.net, dnsbl.sorb.net, zen.spamhaus.org"; \
# Disable chroot environment
    postconf -F '*/*/chroot = n'

# Journaling support
ADD files/rsyslog.conf /etc/rsyslog.conf

# Add startup script
ADD start.sh /start.sh

# Postfix ports
## TCP:2525  - SMTP
RUN sed -i "s/^smtp\(\s\+inet.*\)$/2525\1/" /etc/postfix/master.cf
EXPOSE 2525/tcp

VOLUME /etc/postfix
VOLUME /var/mail
VOLUME /var/log

ENTRYPOINT ["/start.sh"]
CMD [""]

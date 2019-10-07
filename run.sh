#!/bin/ash

[ "${DEBUG}" == "yes" ] && set -x

[ -z "${SMTP_SERVER}" ] && echo "SMTP_SERVER is not set" && exit 1
[ -z "${SMTP_USERNAME}" ] && echo "SMTP_USERNAME is not set" && exit 1
[ -z "${SMTP_PASSWORD}" ] && echo "SMTP_PASSWORD is not set" && exit 1
[ -z "${SERVER_HOSTNAME}" ] && echo "SERVER_HOSTNAME is not set" && exit 1

SMTP_PORT="${SMTP_PORT-587}"

#Get the domain from the server host name
DOMAIN=`echo ${SERVER_HOSTNAME} |awk -F. '{$1="";OFS="." ; print $0}' | sed 's/^.//' | sed 's/ /./'`

# Set needed config options
echo "Setting config options"
postconf -e "myhostname = ${SERVER_HOSTNAME}"
postconf -e "mydomain = ${DOMAIN}"
postconf -e "mydestination = \$myhostname"
postconf -e "myorigin = \$mydomain"
postconf -e "relayhost = [${SMTP_SERVER}]:${SMTP_PORT}"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "transport_maps = hash:/etc/postfix/transport"

echo "Configure email forwarding"
#postconf -e "luser_relay = ${SMTP_USERNAME}"
#postconf -e "local_recipient_maps =" # This line intentionally left blank
postconf -e "virtual_alias_maps = regexp:/etc/postfix/virtual_alias"
if [ ! -z "${EMAIL_FILTER}" ]; then
  echo "/${EMAIL_FILTER}.*@${DOMAIN}/ ${SMTP_USERNAME}" >> /etc/postfix/virtual_alias
else 
  echo "/.*@${DOMAIN}/ ${SMTP_USERNAME}" >> /etc/postfix/virtual_alias
fi
postmap /etc/postfix/virtual_alias

# Create sasl_passwd file with auth credentials
# Since this is a Docker, we will replace the existing file, if one exists
echo "Adding SASL authentication configuration"
echo "[${SMTP_SERVER}]:${SMTP_PORT} ${SMTP_USERNAME}:${SMTP_PASSWORD}" >> /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

#Set header tag  
if [ ! -z "${SMTP_HEADER_TAG}" ]; then
  postconf -e "header_checks = regexp:/etc/postfix/header_tag"
  echo -e "/^MIME-Version:/i PREPEND RelayTag: $SMTP_HEADER_TAG\n/^Content-Transfer-Encoding:/i PREPEND RelayTag: $SMTP_HEADER_TAG" > /etc/postfix/header_tag
  echo "Setting configuration option SMTP_HEADER_TAG with value: ${SMTP_HEADER_TAG}"
fi

#Check for subnet restrictions
nets='10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16'
newnets=`echo $SMTP_NETWORKS | sed 's/,/\ /g'`

if [ ! -z "${SMTP_NETWORKS}" ]; then
        for i in $newnets; do
                if `echo $i | grep -Eq "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}"` ; then
                        nets="$nets, $i"
                else
                        echo "$i is not in proper IPv4 subnet format. Ignoring."
                fi
        done
fi

echo "Setting networks"
postconf -e "mynetworks = ${nets}"

echo "Setting transports"
echo -e "${SMTP_USERNAME}\t:" >> /etc/postfix/transport
echo -e ".${DOMAIN}\t:" >> /etc/postfix/transport
echo -e "${DOMAIN}\t:" >> /etc/postfix/transport
echo -e "*\tdiscard:" >> /etc/postfix/transport
postmap /etc/postfix/transport

# Finally run the postfix new aliases
newaliases

#Start services
supervisord -c /etc/supervisord.conf

#Dockerfile for a Postfix email relay service
FROM alpine:3.10.2
LABEL maintainer="Patrick Gardella pgardella@gmail.com"
LABEL version="1.0"
LABEL description="An SMTP server for testing which forwards all email recieved to a single email address"

RUN apk add --update \
    cyrus-sasl cyrus-sasl-plain cyrus-sasl-crammd5 cyrus-sasl-digestmd5 mailx \
    supervisor postfix rsyslog \
    && rm -rf /var/cache/apk/*

RUN sed -i -e 's/inet_interfaces = localhost/inet_interfaces = all/g' /etc/postfix/main.cf

COPY etc/*.conf /etc/
COPY etc/rsyslog.d/* /etc/rsyslog.d/
COPY etc/supervisord.d/*.ini /etc/supervisord.d/
COPY run.sh /
RUN chmod +x /run.sh

EXPOSE 25
CMD ["/run.sh"]
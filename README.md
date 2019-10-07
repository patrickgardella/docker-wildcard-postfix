# docker-wildcard-postfix

Simple Postfix SMTP TLS relay [docker](http://www.docker.com) image with no local authentication enabled (to be run in a secure LAN) that forwards all email to a single email address.

We needed a server for testing applications which would let us create unlimited email addresses under a single domain. All emails sent to this SMTP server will get forwarded to the email address passed in as the SMTP_USERNAME. A regex can be provided via the EMAIL_FILTER parameter which will only forward emails that match that regex. This will help reduce the amount of spam you will receive otherwise.

It also includes rsyslog to enable logging to stdout.

## Build instructions

Clone this repo and then:

    cd docker-postfix
    docker build -t postfix .

Or you can use the provided [docker-compose](https://github.com/patrickgardella/docker-wildcard-postfix/blob/master/docker-compose.dev.yml) files:

    docker-compose -f docker-compose.yml -f docker-compose.dev.yml build

For more information on using multiple compose files [see here](https://docs.docker.com/compose/production/). 

You can also find a prebuilt docker image from [Docker Hub](https://registry.hub.docker.com/u/pgardella/wildcard-postfix/), which can be pulled with this command:

    docker pull patrickgardella/wildcard-postfix:latest

## How to run it

The following environmental variables need to be passed to the container:

* `SMTP_SERVER` Server address of the SMTP server to use.
* `SMTP_PORT` (Optional, Default value: 587) Port address of the SMTP server to use.
* `SMTP_USERNAME` Username to authenticate with.
* `SMTP_PASSWORD` Password of the SMTP user.
* `SERVER_HOSTNAME` Server hostname for the Postfix container. Emails will appear to come from the hostname's domain.

The following env variable(s) are optional:
* `EMAIL_FILTER` This is a regex to identify which emails will be forwarded. (See notes below)
* `SMTP_HEADER_TAG` This will add a header for tracking messages upstream. Helpful for spam filters. Will appear as "RelayTag: ${SMTP_HEADER_TAG}" in the email headers.
* `SMTP_NETWORKS` Setting this will allow you to add additional, comma seperated, subnets to use the relay. Used like
    -e SMTP_NETWORKS='xxx.xxx.xxx.xxx/xx,xxx.xxx.xxx.xxx/xx'

The following environmental variable is constructed internally:
* `DOMAIN` Using the `SERVER_HOSTNAME` variable, extract just the domain information. For example, if `SERVER_HOSTNAME` is "helpdesk.mycompany.com", the generated `DOMAIN` would be "mycompany.com".

To use this container from anywhere, the 25 port or the one specified by `SMTP_PORT` needs to be exposed to the docker host server:

    docker run -d --name postfix -p "25:25"  \ 
           -e SMTP_SERVER=smtp.bar.com \
           -e SMTP_USERNAME=foo@bar.com \
           -e SMTP_PASSWORD=XXXXXXXX \
           -e SERVER_HOSTNAME=helpdesk.mycompany.com \
           patrickgardella/postfix
    
If you are going to use this container from other docker containers then it's better to just publish the port:

    docker run -d --name postfix -P \
           -e SMTP_SERVER=smtp.bar.com \
           -e SMTP_USERNAME=foo@bar.com \
           -e SMTP_PASSWORD=XXXXXXXX \
           -e SERVER_HOSTNAME=helpdesk.mycompany.com \           
           patrickgardella/postfix

Or if you can start the service using the provided [docker-compose](https://github.com/patrickgardella/docker-wildcard-postfix/blob/master/docker-compose.yml) file for production use:

    docker-compose up -d

To see the email logs in real time:

    docker logs -f postfix

## Sending restricted

To prevent as many spam messages as possible, and to prevent an open relay, we restrict sending emails only from the `${DOMAIN}` or its subdomains via transport_maps, and only those which match the `EMAIL_FILTER` regex.

The regular expression will be used to filter emails to forward on. All other emails will be marked as user not found, and rejected. For example, if the regex is `^test.*`, any email that begins with the word "test" will get forwarded. By default, any 

Under the covers, the run script will append `@DOMAIN` to the regex to work around some of the ways Postfix [works](https://unix.stackexchange.com/a/218609).

Any email which does not match the regex will be returned with a error message: `550 5.1.1 The email account that you tried to reach does not exist. Please try double-checking the recipient's email address for typos or unnecessary spaces.`

## A note about using Gmail as a relay

Gmail by default [does not allow email clients that don't use OAUTH 2](http://googleonlinesecurity.blogspot.co.uk/2014/04/new-security-measures-will-affect-older.html) for authentication (like Thunderbird or Outlook). First you need to enable access to "Less secure apps" on your [google settings](https://www.google.com/settings/security/lesssecureapps).

Also take into account that email `From:` header will contain the email address of the account being used to
authenticate against the Gmail SMTP server(SMTP_USERNAME), the one on the email will be ignored by Gmail unless you [add it as an alias](https://support.google.com/mail/answer/22370).

Finally, to use Gmail, you should use an [Application Specific Password](https://support.google.com/mail/answer/185833?hl=en).

## A Final note

Postfix is a complicated piece of software, and I am trying to make it do something that its not specifically designed to do. If you have suggestions for improving how I have done this, please raise an [Issue]().

## Thanks to

[Juan Luis Baptiste](https://github.com/juanluisbaptiste/docker-postfix) for the foundation of this image.

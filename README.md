# What is this
This Dockerfile (available as dmitriiageev/postfix) gives you Postfix email server.
Postfix is a free and open-source mail transfer agent (MTA).

# Usage
Using the pre-built image from docker hub, you can start your email server by running:

```
$ docker run \
--name postfix \
-detach \
--publish 25:2525/tcp \
--volume /local/maildir:/var/mail \
--volume /local/log/storage:/var/log \
docker-postfix my_domain_name.com my_host.domain_name.com
```
This will connect SMTP port 25 to the host and mount volume folders as in the example given above.

__NB.__ If you are using SELinux, make sure you have set the right context to the volume folders.

# Test email
To make sure the email server is working, send a test email via the command line:

echo -e "To: Bob <bob@example.com>\nFrom: Bill <bill@example.com>\nSubject: Test email\n\nThis is a test email message" | mailx -v -S smtp=smtp://... -S from=bill@example.com -t

# Test email with TLS
echo -e "To: Bob <bob@example.com>\nFrom: Bill <bill@example.com>\nSubject: Test email\n\nThis is a test email message" | mailx -v -S smtp-use-starttls -S ssl-verify=ignore -S smtp=smtp://... -S from=bill@example.com -t

# TODO

* Add TLS support
* Add SASL support
* Change base container from __debian-slim__ to __alpine__.

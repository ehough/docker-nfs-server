FROM alpine:latest

# install Bash and nfs-utils
RUN apk --update upgrade && apk add bash nfs-utils && rm -rf /var/cache/apk/*

ADD ./entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 2049

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

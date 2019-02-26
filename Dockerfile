FROM alpine:edge

LABEL maintainer "jon.treharne@googlemail.com"

COPY ./IAMAdmin.sh /tmp/IAMAdmin.sh

RUN apk upgrade

RUN apk add bash python py2-pip

RUN pip install awscli

USER root

ENTRYPOINT ["/bin/bash", "/tmp/IAMAdmin.sh"]

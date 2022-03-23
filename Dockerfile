FROM ubuntu:20.04
MAINTAINER VP

WORKDIR /sync
COPY sync.sh .
RUN apt-get update
RUN apt-get install -y jq curl
RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.23.1/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

CMD [ "bash", "sync.sh" ]

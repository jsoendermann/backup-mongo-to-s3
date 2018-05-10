FROM mongo:latest
LABEL maintainer="Jan Soendermann <jan.soendermann+git@gmail.com>"

RUN apt-get update && \
  apt-get install -y cron bzip2 openssl python python-pip && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install awscli

WORKDIR /scripts

ADD backup.sh .
ADD entrypoint.sh .
RUN chmod +x ./*

VOLUME /tmp-dir

ENTRYPOINT [ "./entrypoint.sh" ]
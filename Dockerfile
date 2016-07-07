FROM centos:centos7

MAINTAINER Sachandhan Ganesh <sachan.ganesh@gmail.com>

# Basic packages
RUN rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm \
  && yum -y install passwd sudo git wget curl vim openssl openssh openssh-server openssh-clients

# Create user
RUN useradd hiroakis \
 && echo "main" | passwd main --stdin \
 && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
 && sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config \
 && echo "main ALL=(ALL) ALL" >> /etc/sudoers.d/main

# Redis
RUN yum install -y redis

# RabbitMQ
RUN yum install -y erlang \
  && rpm --import http://www.rabbitmq.com/rabbitmq-signing-key-public.asc \
  && rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.1.4/rabbitmq-server-3.1.4-1.noarch.rpm \
  && git clone git://github.com/joemiller/joemiller.me-intro-to-sensu.git \
  && cd joemiller.me-intro-to-sensu/; ./ssl_certs.sh clean && ./ssl_certs.sh generate \
  && mkdir /etc/rabbitmq/ssl \
  && cp /joemiller.me-intro-to-sensu/server_cert.pem /etc/rabbitmq/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/server_key.pem /etc/rabbitmq/ssl/key.pem \
  && cp /joemiller.me-intro-to-sensu/testca/cacert.pem /etc/rabbitmq/ssl/
ADD ./files/config/rabbitmq.config /etc/rabbitmq/
RUN rabbitmq-plugins enable rabbitmq_management

# Sensu server
ADD ./files/repo/sensu.repo /etc/yum.repos.d/
RUN yum install -y sensu
ADD ./files/config/config.json /etc/sensu/
RUN mkdir -p /etc/sensu/ssl \
  && cp /joemiller.me-intro-to-sensu/client_cert.pem /etc/sensu/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/client_key.pem /etc/sensu/ssl/key.pem

# uchiwa
RUN yum install -y uchiwa
ADD ./files/config/uchiwa.json /etc/sensu/

# influxdb
ADD ./files/repo/influxdb.repo /etc/yum.repos.d/
RUN yum install -y influxdb
RUN sudo service influxdb start

# supervisord
RUN wget http://peak.telecommunity.com/dist/ez_setup.py;python ez_setup.py \
  && easy_install supervisor
ADD files/supervisord.conf /etc/supervisord.conf

RUN /etc/init.d/sshd start && /etc/init.d/sshd stop

EXPOSE 22 3000 4567 5671 15672

CMD ["/usr/bin/supervisord"]

# client
ADD ./files/config/client.json /etc/sensu/conf.d/
RUN touch /var/log/sensu/sensu-client.log
RUN /opt/sensu/bin/sensu-client start -c /etc/sensu/conf.d/client.json --log /var/log/sensu/sensu-client.log -b

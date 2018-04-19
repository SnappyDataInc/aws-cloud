FROM tianon/centos

MAINTAINER SnappyData, Inc.

USER root

RUN mkdir -p /opt/snappydata

RUN yum -y install epel-release && yum clean all -y
RUN yum -y install nss_wrapper gettext && yum clean all -y
RUN yum -y install curl which tar sudo openssh-server openssh-clients passwd supervisor bind-utils; yum clean all -y
RUN yum -y install wget; yum clean all -y

RUN service sshd restart

RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

COPY jdk-8u131-linux-x64.rpm /opt/snappydata
RUN rpm -ivh /opt/snappydata/jdk-8u131-linux-x64.rpm
RUN rm -rf /opt/snappydata/jdk-8u131-linux-x64.rpm

ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin

#ADD snappydata /opt/snappydata
COPY . /opt/snappydata/
COPY start /usr/local/bin/
RUN chmod o+x /usr/local/bin/start
WORKDIR /opt/snappydata

RUN chgrp -R 0 /opt/snappydata
RUN chmod -R g+rw /opt/snappydata
RUN find /opt/snappydata -type d -exec chmod g+x {} +

CMD ["/usr/local/bin/start", "all"]

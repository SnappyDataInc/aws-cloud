FROM tianon/centos

MAINTAINER SnappyData, Inc.

USER root

# TODO Comment out below directive and fix following TODOs to reduce image size
# RUN mkdir -p /opt/snappydata

RUN yum -y install epel-release nss_wrapper gettext && \
    yum -y install curl which tar sudo openssh-server openssh-clients passwd supervisor bind-utils nc wget && \
    yum clean all -y

RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa && \
    cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# COPY . /opt/snappydata/
# RUN rpm -ivh /opt/snappydata/jre-8u172-linux-x64.rpm && \
#     rm -f /opt/snappydata/jre-8u172-linux-x64.rpm
# TODO Uncomment below directive and comment out above two to reduce image size
RUN wget -q -O /opt/jre-8u172-linux-x64.rpm https://s3-us-west-2.amazonaws.com/azure-templates/jre-8u172-linux-x64.rpm && \
    rpm -ivh /opt/jre-8u172-linux-x64.rpm && \
    rm -f /opt/jre-8u172-linux-x64.rpm

ENV JAVA_HOME /usr/java/default
ENV PATH $PATH:$JAVA_HOME/bin

# RUN chgrp -R 0 /opt/snappydata && \
#    chmod -R g+rw /opt/snappydata && \
#    find /opt/snappydata -type d -exec chmod g+x {} +
# TODO Uncomment below directive and comment out above two to reduce image size
RUN wget -q -O /opt/snappydata-1.0.2-bin.tar.gz https://github.com/SnappyDataInc/snappydata/releases/download/v1.0.2/snappydata-1.0.2-bin.tar.gz && \
    tar -C /opt -xf /opt/snappydata-1.0.2-bin.tar.gz && \
    mv /opt/snappydata-1.0.2-bin /opt/snappydata && \
    rm -f /opt/snappydata-1.0.2-bin.tar.gz && \
#    wget -q -O /opt/snappydata/jars/aws-java-sdk-1.7.4.jar http://central.maven.org/maven2/com/amazonaws/aws-java-sdk/1.7.4/aws-java-sdk-1.7.4.jar && \
#    wget -q -O /opt/snappydata/jars/hadoop-aws-2.7.3.jar http://central.maven.org/maven2/org/apache/hadoop/hadoop-aws/2.7.3/hadoop-aws-2.7.3.jar && \
    wget -q -O /opt/snappydata/jars/gcs-connector-latest-hadoop2.jar https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-latest-hadoop2.jar && \
    wget -q -O /opt/snappydata/jars/snappydata-zeppelin_2.11-0.7.3.2.jar https://github.com/SnappyDataInc/zeppelin-interpreter/releases/download/v0.7.3.2/snappydata-zeppelin_2.11-0.7.3.2.jar && \
    chgrp -R 0 /opt/snappydata && \
    chmod -R g+rw /opt/snappydata && \
    find /opt/snappydata -type d -exec chmod g+x {} +

COPY start /usr/local/bin/
RUN chmod o+x /usr/local/bin/start
WORKDIR /opt/snappydata

EXPOSE 5050

CMD ["/usr/local/bin/start", "all"]

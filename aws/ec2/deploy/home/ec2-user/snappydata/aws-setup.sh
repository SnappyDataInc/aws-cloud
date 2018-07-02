#!/bin/bash
#
# Copyright (c) 2017 SnappyData, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You
# may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License. See accompanying
# LICENSE file.
#

pushd /home/ec2-user/snappydata > /dev/null

source ec2-variables.sh

# Check if enterprise version to be used.
if [[ "${SNAPPYDATA_VERSION}" = "ENT" ]]; then
  echo "Setting up the cluster with SnappyData Enterprise edition ..."
  # wget -q "https://raw.githubusercontent.com/SnappyDataInc/snappy-cloud-tools/test-02/aws/ec2/deploy/home/ec2-user/snappydata/ent-aws-setup.sh"
  sh ent-aws-setup.sh
  ENT_SETUP=`echo $?`
  # rm -f ent-aws-setup.sh
  popd > /dev/null
  exit ${ENT_SETUP}
fi

sudo yum -y -q remove  jre-1.7.0-openjdk
sudo yum -y -q install java-1.8.0-openjdk-devel

# Download and extract the appropriate distribution.
sh fetch-distribution.sh

# Do it again to read new variables.
source ec2-variables.sh

# Stop an already running cluster, if so.
# sh "${SNAPPY_HOME_DIR}/sbin/snappy-stop-all.sh"

echo "$LOCATORS" > locator_list
echo "$LEADS" > lead_list
echo "$SERVERS" > server_list
echo "$ZEPPELIN_HOST" > zeppelin_server

if [[ -e snappy-env.sh ]]; then
  mv snappy-env.sh "${SNAPPY_HOME_DIR}/conf/"
fi

# Place the list of locators, leads and servers under conf directory
if [[ -e locators ]]; then
  mv locators "${SNAPPY_HOME_DIR}/conf/"
else
  cp locator_list "${SNAPPY_HOME_DIR}/conf/locators"
fi

# Enable jmx-manager for pulse to start - DISCONTINUED with SnappyData 0.9
# sed -i '/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ -jmx-manager=true -jmx-manager-start=true/}}' "${SNAPPY_HOME_DIR}/conf/locators"
# Configure hostname-for-clients
sed -i '/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/\([^ ]*\)\(.*\)$/\1\2 -hostname-for-clients=\1/}}' "${SNAPPY_HOME_DIR}/conf/locators"

echo "Created conf/locators"

HEAPSTR=""
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"
for node in ${SERVERS}; do
    export SERVER_RAM=`ssh $SSH_OPTS "$node" "free -gt | grep Total"`
    HEAP=`echo $SERVER_RAM | awk '{print $2}'` && HEAP=`echo $HEAP \* 0.8 / 1 | bc` && HEAPSTR="-heap-size=${HEAP}g"
    break
done

if [[ -e leads ]]; then
  mv leads "${SNAPPY_HOME_DIR}/conf/"
else
  cp lead_list "${SNAPPY_HOME_DIR}/conf/leads"
fi

INTERPRETER_VERSION="0.7.3"

if [[ "${ZEPPELIN_HOST}" != "NONE" ]]; then
  echo "Configuring Zeppelin interpreter properties..."
  # Add interpreter jar to snappydata's jars directory
  INTERPRETER_JAR="snappydata-zeppelin_2.11-${INTERPRETER_VERSION}.jar"
  INTERPRETER_URL="https://github.com/SnappyDataInc/zeppelin-interpreter/releases/download/v${INTERPRETER_VERSION}/${INTERPRETER_JAR}"
  wget -q "${INTERPRETER_URL}" && mv ${INTERPRETER_JAR} ${SNAPPY_HOME_DIR}/jars/
  INT_DOWNLOAD=`echo $?`
  if [[ ${INT_DOWNLOAD} != 0 ]]; then
    echo "ERROR: Could not download Zeppelin interpreter for SnappyData from ${INTERPRETER_URL}"
    export ZEPPELIN_HOST="NONE"
  else
    # Enable interpreter on lead
    sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ -zeppelin.interpreter.enable=true /}}" "${SNAPPY_HOME_DIR}/conf/leads"
  fi
fi

sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ ${HEAPSTR}/}}" "${SNAPPY_HOME_DIR}/conf/leads"

if [[ -e servers ]]; then
  mv servers "${SNAPPY_HOME_DIR}/conf/"
else
  cp server_list "${SNAPPY_HOME_DIR}/conf/servers"
fi

# Configure hostname-for-clients and heap memory
sed -i '/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/\([^ ]*\)\(.*\)$/\1\2 -hostname-for-clients=\1/}}' "${SNAPPY_HOME_DIR}/conf/servers"
sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ ${HEAPSTR}/}}" "${SNAPPY_HOME_DIR}/conf/servers"
echo "Created conf/servers"

# Set SPARK_DNS_HOST to public hostname of first lead so that SnappyData Pulse UI links work fine.
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"
for node in ${LEADS}; do
    export LEAD_DNS_NAME=`ssh $SSH_OPTS "$node" "wget -q -O - http://169.254.169.254/latest/meta-data/public-hostname"`
    break
done
echo "SPARK_PUBLIC_DNS=${LEAD_DNS_NAME}" >> ${SNAPPY_HOME_DIR}/conf/spark-env.sh
echo "Set SPARK_PUBLIC_DNS to ${LEAD_DNS_NAME}"

OTHER_LOCATORS=`cat locator_list | sed '1d'`
echo "$OTHER_LOCATORS" > other-locators

# Copy this extracted directory to all the other instances
sh copy-dir.sh "${SNAPPY_HOME_DIR}"  other-locators

sh copy-dir.sh "${SNAPPY_HOME_DIR}"  lead_list

sh copy-dir.sh "${SNAPPY_HOME_DIR}"  server_list

DIR=`readlink -f zeppelin-setup.sh`
DIR=`echo "$DIR"|sed 's@/$@@'`
DIR=`dirname "$DIR"`

for node in ${OTHER_LOCATORS}; do
    ssh "$node" "sudo yum -y -q remove jre-1.7.0-openjdk"
    ssh "$node" "sudo yum -y -q install java-1.8.0-openjdk-devel"
done
for node in ${LEADS}; do
    ssh "$node" "sudo yum -y -q remove jre-1.7.0-openjdk"
    ssh "$node" "sudo yum -y -q install java-1.8.0-openjdk-devel"
done
for node in ${SERVERS}; do
    ssh "$node" "sudo yum -y -q remove jre-1.7.0-openjdk"
    ssh "$node" "sudo yum -y -q install java-1.8.0-openjdk-devel"
done

# Launch the SnappyData cluster
sh "${SNAPPY_HOME_DIR}/sbin/snappy-start-all.sh"

# Setup and launch zeppelin, if configured.
if [[ "${ZEPPELIN_HOST}" != "NONE" ]]; then
  for server in "$ZEPPELIN_HOST"; do
    ssh "$server" -o StrictHostKeyChecking=no "mkdir -p ~/snappydata"
    scp -q -o StrictHostKeyChecking=no ec2-variables.sh "${server}:~/snappydata"
    scp -q -o StrictHostKeyChecking=no zeppelin-setup.sh "${server}:~/snappydata"
    scp -q -o StrictHostKeyChecking=no fetch-distribution.sh "${server}:~/snappydata"
  done
  ssh "$ZEPPELIN_HOST" -t -t -o StrictHostKeyChecking=no "sh ${DIR}/zeppelin-setup.sh"
fi

popd > /dev/null

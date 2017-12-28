#!/usr/bin/env bash
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

export DOWNLOADS_DIR=/snappydata
export SNAPPY_HOME_DIR=/opt/snappydata
export ZEPPELIN_DIR=/opt/zeppelin

PUBLIC_HOSTNAME=`wget -q -O - http://169.254.169.254/latest/meta-data/public-hostname`
PRIVATE_IP=`wget -q -O - http://169.254.169.254/latest/meta-data/local-ipv4`

# Stop an already running cluster, if so.
sh "${SNAPPY_HOME_DIR}/sbin/snappy-stop-all.sh"

echo "$LOCATORS" > locator_list
echo "$LEADS" > lead_list
echo "$SERVERS" > server_list
echo "$ZEPPELIN_HOST" > zeppelin_server

LOCATORS=`cat locator_list`
LEADS=`cat lead_list`
SERVERS=`cat server_list`

if [[ -e snappy-env.sh ]]; then
  mv snappy-env.sh "${SNAPPY_HOME_DIR}/conf/"
fi

# Place the list of locators, leads and servers under conf directory
if [[ -e locators ]]; then
  mv locators "${SNAPPY_HOME_DIR}/conf/"
else
  cp locator_list "${SNAPPY_HOME_DIR}/conf/locators"
fi

if [[ -e leads ]]; then
  mv leads "${SNAPPY_HOME_DIR}/conf/"
else
  cp lead_list "${SNAPPY_HOME_DIR}/conf/leads"
fi

if [[ "${ZEPPELIN_HOST}" != "NONE" ]]; then
  # Enable interpreter on lead. Interpreter jar is already available at the mentioned location in the 1.0.0 AMI
  sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ -zeppelin.interpreter.enable=true -classpath=/opt/zeppelin/snappydata-zeppelin.jar/}}" "${SNAPPY_HOME_DIR}/conf/leads"
fi

if [[ -e servers ]]; then
  mv servers "${SNAPPY_HOME_DIR}/conf/"
else
  cp server_list "${SNAPPY_HOME_DIR}/conf/servers"
fi

# Configure hostname-for-clients
sed -i '/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/\([^ ]*\)\(.*\)$/\1\2 -hostname-for-clients=\1/}}' "${SNAPPY_HOME_DIR}/conf/servers"

OTHER_LOCATORS=`cat locator_list | sed '1d'`
echo "$OTHER_LOCATORS" > other-locators

DIR=`readlink -f zeppelin-setup.sh`
DIR=`echo "$DIR"|sed 's@/$@@'`
DIR=`dirname "$DIR"`

# TODO Do this at server and lead vm and not at locator vm as it could be of different type.
# Calculate heap and off-heap sizes.
# Set heap to be 8GB or 1/4th of considered memory, whichever is higher. Remaining for off-heap.
MYRAM=`free -gt | grep Total | awk '{print $2}'`
AVAIL=`echo $MYRAM \* 0.8 / 1 | bc`
HEAP=`echo $AVAIL \* 0.25 / 1 | bc`
HEAP=$(($HEAP < 4 ? 4 : $HEAP))
HEAP=$(($HEAP > 8 ? 8 : $HEAP))
OFFHEAP=`echo $AVAIL - $HEAP | bc`

if [[ $HEAP -gt $AVAIL ]]; then
  HEAPSTR=""
else
  HEAPSTR="-heap-size=${HEAP}g"
fi

if [[ $OFFHEAP -le 0 ]]; then
  OFFHEAPSTR=""
else
  OFFHEAPSTR="-memory-size=${OFFHEAP}g"
fi

echo "Total: $MYRAM, considered: $AVAIL, heap: $HEAP, off-heap: $OFFHEAP" >> memory-breakup.txt

addProps() {
  grep "$1" "$2"
  if [[ "$?" -ne 0 ]]; then
    sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ $3/}}" "$2"
  fi
}

addProps "-heap-size" "${SNAPPY_HOME_DIR}/conf/servers" "${HEAPSTR}"
addProps "-memory-size" "${SNAPPY_HOME_DIR}/conf/servers" "${OFFHEAPSTR}"
addProps "-heap-size" "${SNAPPY_HOME_DIR}/conf/leads" "${HEAPSTR}"
addProps "-memory-size" "${SNAPPY_HOME_DIR}/conf/leads" "${OFFHEAPSTR}"

# TODO Set SPARK_DNS_HOST to public hostname of Lead so that SnappyData Pulse UI links work fine.

copyConfs() {
  for node in "$1"; do
    echo "Copying conf files to ${node}..."
    scp -q -o StrictHostKeyChecking=no ${SNAPPY_HOME_DIR}/conf/locators "${node}:/opt/snappydata/conf"
    scp -q -o StrictHostKeyChecking=no ${SNAPPY_HOME_DIR}/conf/servers "${node}:/opt/snappydata/conf"
    scp -q -o StrictHostKeyChecking=no ${SNAPPY_HOME_DIR}/conf/leads "${node}:/opt/snappydata/conf"
  done
}

# Copy conf files to all nodes
# TODO Iterate over file entries and not over variables.
copyConfs "${OTHER_LOCATORS}"
copyConfs "${LEADS}"
copyConfs "${SERVERS}"

echo -e "export SNAPPY_HOME_DIR=${SNAPPY_HOME_DIR}" >> ec2-variables.sh

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
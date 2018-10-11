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

echo "$LOCATORS" > locator_list
echo "$LEADS" > lead_list
echo "$SERVERS" > server_list
echo "$LOCATOR_PRIVATE_IPS" > locator_private_list
echo "$LEAD_PRIVATE_IPS" > lead_private_list
echo "$SERVER_PRIVATE_IPS" > server_private_list

echo "$ZEPPELIN_HOST" > zeppelin_server
OTHER_LOCATORS=`cat locator_list | sed '1d'`
echo "$OTHER_LOCATORS" > other-locators
ALL_NODES=( "${OTHER_LOCATORS} ${LEADS} ${SERVERS}" )
SNAPPY_HOME_DIR=/opt/snappydata
SSH_OPTS="-o StrictHostKeyChecking=no -o LogLevel=error"

# Check if enterprise version is to be setup.
# TODO More work needed below, if this needs to be supported. Currently, check fails always.
if [[ "${SNAPPYDATA_VERSION}" = "ENT" ]]; then
  echo "Setting up the cluster with SnappyData Enterprise edition ..."
  bash ent-aws-setup.sh
  ENT_SETUP=`echo $?`
  popd > /dev/null
  exit ${ENT_SETUP}
fi

sudo yum -y -q remove  jre-1.7.0-openjdk
sudo yum -y -q install java-1.8.0-openjdk-devel

# TODO support cluster upgrade feature

SETUP_EXISTS="true"

# Fetch the tarball only if snappydata is not already present.
if [[ ! -d "${SNAPPY_HOME_DIR}" ]]; then
  SETUP_EXISTS="false"
  # Download and extract the appropriate distribution.
  if [[ "${PRIVATE_BUILD_PATH}" = "NONE" ]]; then
    bash fetch-distribution.sh
    if [[ "$?" != 0 ]]; then
      exit 2
    fi
  else
    PRIVATE_BUILD_FILE=`basename "${PRIVATE_BUILD_PATH}"`
    UNTARRED_DIR=`tar -tf "${PRIVATE_BUILD_FILE}" | head -1 | cut -d "/" -f1`
    echo "Name of the extracted directory of snappydata tarball would be ${UNTARRED_DIR}"
    tar -xf "${PRIVATE_BUILD_FILE}"
    if [[ $? != 0 ]]; then
      echo "Could not extract the provided snappydata tarball. Exiting."
      echo "    WARNING: Your EC2 instances may still be running!"
      exit 2
    fi
    sudo rm -rf "${SNAPPY_HOME_DIR}" && sudo mv "${UNTARRED_DIR}" "${SNAPPY_HOME_DIR}"
    echo -e "export SNAPPY_HOME_DIR=${SNAPPY_HOME_DIR}" >> ec2-variables.sh
  fi
fi

# Do it again to read new variables.
source ec2-variables.sh

if [[ ! -d "${SNAPPY_HOME_DIR}" ]]; then
  echo "Could not set up SnappyData product directory, exiting."
  echo "    WARNING: Your EC2 instances may still be running!"
  exit 2
fi
# Stop an already running cluster, if so.
# sh "${SNAPPY_HOME_DIR}/sbin/snappy-stop-all.sh"

if [[ -e snappy-env.sh ]]; then
  mv snappy-env.sh "${SNAPPY_HOME_DIR}/conf/"
fi

sed "s/^/ -hostname-for-clients=/" locator_list > locator_hostnames_list
sed "s/^/ -hostname-for-clients=/" server_list > server_hostnames_list

ALL_CONF="${LOCATOR_CONF}${SERVER_CONF}${LEAD_CONF}"
if [[ "${SETUP_EXISTS}" = "false" ]] || [[ "${ALL_CONF}" != "" ]]; then
  paste -d '' locator_private_list locator_hostnames_list > "${SNAPPY_HOME_DIR}/conf/locators"
  paste -d '' server_private_list server_hostnames_list > "${SNAPPY_HOME_DIR}/conf/servers"
  cat lead_private_list > "${SNAPPY_HOME_DIR}/conf/leads"

  sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ ${LOCATOR_CONF}/}}" "${SNAPPY_HOME_DIR}/conf/locators"
  sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ ${SERVER_CONF}/}}" "${SNAPPY_HOME_DIR}/conf/servers"
  sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ ${LEAD_CONF}/}}" "${SNAPPY_HOME_DIR}/conf/leads"

  # Enable jmx-manager for pulse to start - DISCONTINUED with SnappyData 0.9
  # sed -i '/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ -jmx-manager=true -jmx-manager-start=true/}}' "${SNAPPY_HOME_DIR}/conf/locators"
  # Configure hostname-for-clients
  # sed -i '/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/\([^ ]*\)\(.*\)$/\1\2 -hostname-for-clients=\1/}}' "${SNAPPY_HOME_DIR}/conf/locators"

  # Check if config options already specify -heap-size or -memory-size
  echo "${SERVER_CONF} ${LEAD_CONF}" | grep -e "\-memory\-size\=" -e "\-heap\-size\="
  HAS_MEMORY_SIZE=`echo $?`

  HEAPSTR=""
  if [[ ${HAS_MEMORY_SIZE} != 0 ]]; then
    SSH_OPTS2="${SSH_OPTS} -o ConnectTimeout=5"
    for node in ${SERVERS}; do
      export SERVER_RAM=`ssh $SSH_OPTS2 "$node" "free -gt | grep Total"`
      HEAP=`echo $SERVER_RAM | awk '{print $2}'` && HEAP=`echo $HEAP \* 0.8 / 1 | bc` && HEAPSTR="-heap-size=${HEAP}g"
      break
    done

    sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ ${HEAPSTR}/}}" "${SNAPPY_HOME_DIR}/conf/leads"
    sed -i "/^#/ ! {/\\$/ ! { /^[[:space:]]*$/ ! s/$/ ${HEAPSTR}/}}" "${SNAPPY_HOME_DIR}/conf/servers"
  fi
else
  # Update public hostname in the locators and servers conf files
  private=(${LOCATOR_PRIVATE_IPS// / })
  public=(${LOCATORS// / })
  length=${#private[@]}

  for ((i=0;i<$length;i++)); do
    searchstr=${private[$i]}
    replacestr=${public[$i]}
    sed -i "/^${searchstr}/{s/-hostname-for-clients=[^ ]*/-hostname-for-clients=${replacestr}/}" "${SNAPPY_HOME_DIR}/conf/locators"
  done

  private=(${SERVER_PRIVATE_IPS// / })
  public=(${SERVERS// / })
  length=${#private[@]}

  for ((i=0;i<$length;i++)); do
    searchstr=${private[$i]}
    replacestr=${public[$i]}
    sed -i "/^${searchstr}/{s/-hostname-for-clients=[^ ]*/-hostname-for-clients=${replacestr}/}" "${SNAPPY_HOME_DIR}/conf/servers"
  done
fi

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

# Set SPARK_PUBLIC_DNS to public hostname of first lead so that SnappyData Pulse UI links work fine.
SSH_OPTS2="${SSH_OPTS} -o ConnectTimeout=5"
for node in ${LEADS}; do
  export LEAD_DNS_NAME=`ssh $SSH_OPTS2 "$node" "wget -q -O - http://169.254.169.254/latest/meta-data/public-hostname"`
  break
done
echo "SPARK_PUBLIC_DNS=${LEAD_DNS_NAME}" >> ${SNAPPY_HOME_DIR}/conf/spark-env.sh
echo "SPARK_PUBLIC_DNS set to ${LEAD_DNS_NAME}"

if [[ "${SETUP_EXISTS}" = "true" ]]; then
  # Copy the conf directory to all the other instances
  sh copy-dir.sh "${SNAPPY_HOME_DIR}/conf"  other-locators
  sh copy-dir.sh "${SNAPPY_HOME_DIR}/conf"  lead_list
  sh copy-dir.sh "${SNAPPY_HOME_DIR}/conf"  server_list
else
  # Copy this extracted directory to all the other instances
  sh copy-dir.sh "${SNAPPY_HOME_DIR}"  other-locators
  sh copy-dir.sh "${SNAPPY_HOME_DIR}"  lead_list
  sh copy-dir.sh "${SNAPPY_HOME_DIR}"  server_list

  for node in ${ALL_NODES}; do
    ssh "$node" "sudo yum -y -q remove jre-1.7.0-openjdk; sudo yum -y -q install java-1.8.0-openjdk-devel"
  done
  for loc in "$OTHER_LOCATORS"; do
    ssh "$loc" "${SSH_OPTS}" "mkdir -p ~/snappydata"
    scp -q "${SSH_OPTS}" aws-setup.sh aws-shutdown.sh ec2-variables.sh zeppelin-setup.sh fetch-distribution.sh "${loc}:~/snappydata"
  done
fi
echo "Configured the cluster."

# Launch the SnappyData cluster
bash "${SNAPPY_HOME_DIR}/sbin/snappy-start-all.sh"
if [[ $? != 0 ]]; then
  echo "Cluster start did not succeed."
  echo "    WARNING: Your EC2 instances may still be running!"
  exit 2
fi

DIR=`readlink -f zeppelin-setup.sh`
DIR=`echo "$DIR"|sed 's@/$@@'`
DIR=`dirname "$DIR"`

# Setup and launch zeppelin, if configured.
if [[ "${ZEPPELIN_HOST}" != "NONE" ]]; then
  for server in "$ZEPPELIN_HOST"; do
    ssh "$server" "${SSH_OPTS}" "mkdir -p ~/snappydata"
    scp -q "${SSH_OPTS}" ec2-variables.sh zeppelin-setup.sh fetch-distribution.sh "${server}:~/snappydata"
  done
  ssh "$ZEPPELIN_HOST" -t -t "${SSH_OPTS}" "sh ${DIR}/zeppelin-setup.sh"
fi

popd > /dev/null

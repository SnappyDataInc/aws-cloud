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

extract() {
  TAR_NAME=`basename ${URL}`
  DIR_NAME=`echo ${TAR_NAME%.tar.gz}`\
  DIR_NO_BIN_NAME=`echo ${DIR_NAME%-bin}`

  if [[ ! -d ${SNAPPY_HOME_DIR} ]]; then
    # Download and extract the distribution tar
    echo "Downloading ${URL}..."
    wget -q "${URL}"
    if [[ $? -ne 0 ]]; then
      echo "SnappyData distribution could not be downloaded successfully. But EC2 instances may still be running."
      exit 2
    fi
    tar -xf "${TAR_NAME}"
    rm -f "${TAR_NAME}" releases latest

    sudo mv ${DIR_NAME} "${SNAPPY_HOME_DIR}"
    sudo chown -R ec2-user:ec2-user "${SNAPPY_HOME_DIR}"
  else
    echo "SnappyData distribution already present."
  fi
}

getLatestUrl() {
  URL="https://github.com/SnappyDataInc/snappydata/releases/download/v1.0.2/snappydata-1.0.2-bin.tar.gz"
  if [[ "${SNAPPYDATA_TARBALL_URL}" != "" ]]; then
    URL="${SNAPPYDATA_TARBALL_URL}"
  else
    wget -q https://github.com/SnappyDataInc/snappydata/releases/latest
    URL_PART=`grep -o "/SnappyDataInc/snappydata/releases/download/[a-zA-Z0-9.\-]**/snappydata-[0-9.]**-bin.tar.gz" latest`
    GREP_RESULT=`echo $?`
    if [[ ${GREP_RESULT} != 0 ]]; then
      echo "Did not find binaries for ${SNAPPYDATA_VERSION} version. Using "`basename ${URL}`
    else
      URL="https://github.com${URL_PART}"
    fi
  fi
}

SNAPPY_HOME_DIR="/opt/snappydata"

if [[ "${SNAPPYDATA_VERSION}" = "LATEST" ]]; then
  getLatestUrl
  extract
elif [[ ! -d ${SNAPPY_HOME_DIR} ]]; then
  wget -q https://github.com/SnappyDataInc/snappydata/releases
  URL_PART=`grep -o "/SnappyDataInc/snappydata/releases/download/[a-zA-Z0-9.\/\-]**${SNAPPYDATA_VERSION}-bin.tar.gz" releases`
  GREP_RESULT=`echo $?`
  if [[ ${GREP_RESULT} != 0 ]]; then
    echo "Did not find binaries for ${SNAPPYDATA_VERSION}, instead will use the available version."
    getLatestUrl
  else
    URL="https://github.com${URL_PART}"
  fi
  extract
else
  echo "SnappyData distribution already present."
fi

echo -e "export SNAPPY_HOME_DIR=${SNAPPY_HOME_DIR}" >> ec2-variables.sh

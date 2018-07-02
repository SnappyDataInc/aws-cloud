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
  TAR_NAME=`echo ${URL} | cut -d'/' -f 9`
  SNAPPY_HOME_DIR=`echo ${TAR_NAME%.tar.gz}`
  SNAPPY_HOME_DIR_NO_BIN=`echo ${SNAPPY_HOME_DIR%-bin}`

  if [[ ! -d ${SNAPPY_HOME_DIR} ]] && [[ ! -d ${SNAPPY_HOME_DIR_NO_BIN} ]]; then
    # Download and extract the distribution tar
    echo "Downloading ${URL}..."
    wget -q "${URL}"
    tar -xf "${TAR_NAME}"

    rm -f "${TAR_NAME}" releases
  fi
  if [[ -d ${SNAPPY_HOME_DIR_NO_BIN} ]]; then
    SNAPPY_HOME_DIR=${SNAPPY_HOME_DIR_NO_BIN}
  fi
}

getLatestUrl() {
  URL="https://github.com/SnappyDataInc/snappydata/releases/download/v1.0.1/snappydata-1.0.1-bin.tar.gz"
}

SNAPPY_HOME_DIR="snappydata-${SNAPPYDATA_VERSION}-bin"
SNAPPY_HOME_DIR_NO_BIN="snappydata-${SNAPPYDATA_VERSION}"

if [[ "${SNAPPYDATA_VERSION}" = "LATEST" ]]; then
  getLatestUrl
  extract
elif [[ ! -d ${SNAPPY_HOME_DIR} ]] && [[ ! -d ${SNAPPY_HOME_DIR_NO_BIN} ]]; then
  wget -q https://github.com/SnappyDataInc/snappydata/releases
  URL_PART=`grep -o "/SnappyDataInc/snappydata/releases/download/[a-zA-Z0-9.\/\-]**${SNAPPYDATA_VERSION}-bin.tar.gz" releases`
  GREP_RESULT=`echo $?`
  if [[ ${GREP_RESULT} != 0 ]]; then
    # Try without '-bin'
    URL_PART=`grep -o "/SnappyDataInc/snappydata/releases/download/[a-zA-Z0-9.\/\-]**${SNAPPYDATA_VERSION}.tar.gz" releases`
    GREP_RESULT=`echo $?`
  fi
  if [[ ${GREP_RESULT} != 0 ]]; then
    echo "Did not find binaries for ${SNAPPYDATA_VERSION}, instead will use the latest version."
    getLatestUrl
  else
    URL="https://github.com${URL_PART}"
  fi
  extract
else
  if [[ -d ${SNAPPY_HOME_DIR_NO_BIN} ]]; then
    SNAPPY_HOME_DIR=${SNAPPY_HOME_DIR_NO_BIN}
  fi
fi

echo -e "export SNAPPY_HOME_DIR=${SNAPPY_HOME_DIR}" >> ec2-variables.sh

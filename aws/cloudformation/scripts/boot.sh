#!/bin/bash -x

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

# Run as root

export HOMESCREEN=$1
export DOWNLOADS_DIR=/snappydata
export SNAPPYDATA_DIR=/opt/snappydata
export ZEPPELIN_DIR=/opt/zeppelin

mkdir -p ${DOWNLOADS_DIR}
cd ${DOWNLOADS_DIR}

printf "\n# `date` START -------------------------------------------------- #\n" >> status.log

sudo yum -y update
# Install CloudFormation helper scripts
#which cfn-signal
#if [[ $? -ne 0 ]]; then
#  apt-get update
#  apt-get -y upgrade
#  apt-get -y install python-setuptools
#  easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
#  printf "# `date` Installed cloudformation helper scripts $?\n" >> status.log
#fi

# Update the urls for various artifacts and scripts.
export SNAPPYDATA_URL="https://github.com/SnappyDataInc/snappydata/releases/download/v1.0.0/snappydata-1.0.0-bin.tar.gz"
export INTERPRETER_URL="https://github.com/SnappyDataInc/zeppelin-interpreter/releases/download/v0.7.2/snappydata-zeppelin-0.7.2.jar"
export NOTEBOOK_URL="https://github.com/SnappyDataInc/zeppelin-interpreter/raw/notes/examples/notebook/notebook.tar.gz"
export CF_SCRIPT_URL="https://raw.githubusercontent.com/SnappyDataInc/snappy-cloud-tools/master/aws/cloudformation/scripts/setup.sh"
printf "# `date` Updated urls $?\n" >> status.log

rm -f setup.sh
wget -q ${CF_SCRIPT_URL}
printf "# `date` Downloaded cloudformation setup script $?\n" >> status.log

bash setup.sh
SETUP_DONE=`echo $?`

printf "\n# `date` END -------------------------------------------------- #\n" >> status.log

exit ${SETUP_DONE}

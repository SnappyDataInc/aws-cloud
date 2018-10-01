## Table of Contents

* [Setting up Cluster with SnappyData Docker Image](#setting-up-cluster-with-snappydata-docker-image)
* [Using Multiple Containers with Docker Compose](#using-multiple-containers-with-docker-compose)
* [SnappyData on Docker Cloud](#run-snappydata-on-docker-cloud)
* [SnappyData with Docker Swarm](#snappydata-with-docker-swarm)
* [Using Kubernetes](#using-kubernetes)

## Setting up Cluster with SnappyData Docker Image
### Prerequisites

Before you begin, ensure that:
* You have Docker installed, configured and it runs successfully on your machine. Refer to the [Docker documentation](http://docs.docker.com/installation) for more information on installing Docker.
* The Docker containers have access to at least 4GB of RAM on your machine.
* To run Docker you may need to modify the RAM used by the virtual machine which is running the Docker daemon. Refer to the Docker documentation for more information.

1. **Verify that your installation is working correctly**

 Run the following command on your machine:
 ```
 $ docker run hello-world
 ```

2. **Start a basic cluster with one data node, one lead, and one locator**

 **For Linux**

 ```
 $ docker run -itd --net=host --name snappydata snappydatainc/snappydata start all
 ```
 **For Mac OS**

 If you are using MAC OS you need to redirect the ports manually.</br>
 Note: If you use `--net=host`, it may not work correctly on the Mac OS.

 Run the following command to start SnappyData Cluster on Mac OS:

 ```
 docker run -d --name=snappydata -p 5050:5050 -p 1527:1527 -p 1528:1528 snappydatainc/snappydata start all -hostname-for-clients=<Machine_IP/Public_IP>
 ```
 The `-hostname-for-clients` parameter sets the IP Address or Host name that this server listens on for client connections. The command may take some time to complete execution.

 The Docker image of SnappyData is built using its Open Source (OSS) version. The image of its Enterprise version will be made available soon.

3. **Check the Docker Process**

 ```
 $ docker ps -a
 
 ```

4. **Check the Docker Logs**<br>
 Run the following command to view the logs of the container process.
 
  ```
 $ docker logs snappydata
Starting sshd service
Generating SSH2 RSA host key:                              [  OK  ]
Generating SSH1 RSA host key:                              [  OK  ]
Generating SSH2 DSA host key:                              [  OK  ]
Starting sshd:                                             [  OK  ]
Logs generated in /opt/snappydata/work/localhost-locator-1/snappylocator.log
SnappyData Locator pid: 131 status: running
  Distributed system now has 1 members.
  Started Thrift locator (Compact Protocol) on: localhost/127.0.0.1[1527]
Logs generated in /opt/snappydata/work/localhost-server-1/snappyserver.log
SnappyData Server pid: 267 status: running
  Distributed system now has 2 members.
  Started Thrift server (Compact Protocol) on: localhost/127.0.0.1[1528]
Logs generated in /opt/snappydata/work/localhost-lead-1/snappyleader.log
SnappyData Leader pid: 420 status: running
  Distributed system now has 3 members.
  Starting job server on: 0.0.0.0[8090]
 ```
 The query results display *Distributed system now has 3 members*.

5. **Connect SnappyData with the Command Line Client**
 ```
 $ docker exec -it snappydata ./bin/snappy
 ```
 
6. **Connect Client on port “1527”**

 ```
 $ snappy> connect client 'localhost:1527';
 ```

7. **View Connections**

 ```
 snappy> show connections;
 CONNECTION0* - 	jdbc:snappydata:thrift://localhost[1527]
 * = current connection
 ```
8. **Check Member Status**

 ```
 snappy> show members;
 ID                                  |HOST                          |KIND                          |STATUS              |THRIFTSERVERS                 |SERVERGROUPS                  
 -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 127.0.0.1(131:locator)<ec><v0>:37815|localhost                     |locator(normal)               |RUNNING             |localhost/127.0.0.1[1527]     |                              
 127.0.0.1(267)<v1>:13054            |localhost                     |datastore(normal)             |RUNNING             |localhost/127.0.0.1[1528]     |                              
 127.0.0.1(420)<v2>:6067             |localhost                     |accessor(normal)              |RUNNING             |                              |IMPLICIT_LEADER_SERVERGROUP   
 
 3 rows selected
 ```
Use Ctrl+D to exit the shell.

9. **Stop the Cluster**

 ```
 $ docker exec -it snappydata ./sbin/snappy-stop-all.sh
 The SnappyData Leader on 192.168.1.12(localhost-lead-1) has stopped.
 The SnappyData Server on 192.168.1.12(localhost-server-1) has stopped.
 The SnappyData Locator on 192.168.1.12(localhost-locator-1) has stopped.
 ```

10. **Stop SnappyData Container**
 ```
 $ docker stop snappydata
 ```

<hr>

## Using Multiple Containers with Docker Compose

**NOTE:**
```
The latest Docker image has not been tested with Docker Compose.
We recommend using Helm charts to launch SnappyData cluster on Kubernetes.
Please visit https://github.com/SnappyDataInc/spark-on-k8s/tree/master/charts/snappydata
```

Download and install the latest version of Docker compose. Refer to the [Docker documentation](https://docs.docker.com/compose/install/) for more information.

1. **Verify the Installation**
Check the version of Docker Compose to verify the installation.

 ```
 $ docker-compose -v
 docker-compose version 1.8.1, build 878cff1
 ```

2. **Set an environment variable called External_IP**

 ```
 export EXTERNAL_IP=<your machine ip>
 ```
 
3. **Use the compose file (docker-compose.yml) file to run Docker Compose**

 Download the [docker-compose.yml](https://raw.githubusercontent.com/SnappyDataInc/snappy-cloud-tools/master/docker/docker-compose.yml) file, and then run it from the downloaded location using the following command:

 ```
 $ docker-compose -f docker-compose.yml up -d
 Creating network "docker_default" with the default driver
 Creating locator1
 Creating server1
 Creating snappy-lead1
 ```
 This creates three containers; a locator, server, and lead. 

 ```
$ docker-compose ps
     Name                  Command               State                        Ports                       
 --------------------------------------------------------------------------------------------------------
 locator1       start locator                    Up      0.0.0.0:10334->10334/tcp, 0.0.0.0:1527->1527/tcp 
 server1        bash -c sleep 10 && start  ...   Up      0.0.0.0:1528->1528/tcp                           
 snappy_lead1   bash -c sleep 20 && start  ...   Up      0.0.0.0:5050->5050/tcp                           

 ```

4. **View the logs**

 Run the following command to view the logs and to verify the services running inside the Docker Compose.
 ```
 $ docker-compose logs
 Attaching to snappy-lead1, server1, locator1
 server1       | Starting SnappyData Server using locators for peer discovery: locator1:10334
 server1       | Starting DRDA server for SnappyData at address server1/172.18.0.3[1528]
 snappy-lead1  | Starting SnappyData Leader using locators for peer discovery: locator1:10334
 server1       | Logs generated in /opt/snappydata/work/localhost-server-1/snappyserver.log
 snappy-lead1  | Logs generated in /opt/snappydata/work/localhost-lead-1/snappyleader.log
 server1       | SnappyData Server pid: 83 status: running
 snappy-lead1  | SnappyData Leader pid: 83 status: running
 server1       |   Distributed system now has 2 members.
 snappy-lead1  |   Distributed system now has 3 members.
 snappy-lead1  |   Other members: docker_server1(83:datastore)<v1>:53707, locator1(87:locator)<v0>:44102
 server1       |   Other members: locator1(87:locator)<v0>:44102
 locator1      | Starting SnappyData Locator using peer discovery on: locator1[10334]
 locator1      | Starting DRDA server for SnappyData at address locator1/172.18.0.2[1527]
 locator1      | Logs generated in /opt/snappydata/work/localhost-locator-1/snappylocator.log
 locator1      | SnappyData Locator pid: 87 status: running
 ```

 The above logs display that the cluster has started successfully on the three containers.

5. **Connect to the cluster (in step 3) using Snappy shell**

 The following example illustrates how to connect to the cluster using Snappy shell. 

 [Download](http://snappydatainc.github.io/snappydata/install) the binary files from the SnappyData repository. Go the location of the **bin** directory in the SnappyData home directory, and then run the following command:

 ```
 $ bin/snappy
 SnappyData version 1.0.0 
 snappy>
 ```
  Note: If you want to connect to SnappyData with DB client tools like dbSchema, DBVisualizer or Squirrel SQL client,  the jar **snappydata-store-client-1.5.4.jar** file available on the official [SnappyData Release page](#https://github.com/SnappyDataInc/snappydata/releases). Refer to the documentation provided by your client tool for instructions on how to make a JDBC connection.
 
6. **Make a JDBC connection**

 ```
 $ snappy> connect client '<Your Machine IP>:1527';
 Using CONNECTION0
 snappy>
 ```
 
7. **List Members**

 ```
 snappy> show members;
 ID                            |HOST                          |KIND                          |STATUS              |NETSERVERS                    |SERVERGROUPS
 -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 3796bf1ff482(135)<v0>:5840    |3796bf1ff482                  |locator(normal)               |RUNNING             |3796bf1ff482/172.18.0.2[1527] |
 7b54228d4d02(131)<v1>:50185   |7b54228d4d02                  |datastore(normal)             |RUNNING             |192.168.1.130/172.18.0.3[1528]|
 e847fed458a6(130)<v2>:35444   |e847fed458a6                  |accessor(normal)              |RUNNING             |                              |IMPLICIT_LEADER_SERVERGROUP

 3 rows selected
 snappy>
 ```

8. **View Connections**

 ```
 snappy> show connections;
 CONNECTION0* -
  jdbc:gemfirexd://localhost[1528]/
 * = current connection
 ```

9. **Stop Docker Compose**

 To stop and remove containers from the Docker Engine, run the command:

 ```
 $ docker-compose -f docker-compose.yml down
 Stopping snappy_lead1 ... done
 Stopping server1 ... done
 Stopping locator1 ... done
 Removing snappy_lead1 ... done
 Removing server1 ... done
 Removing locator1 ... done
 Removing network dockercompose_snappydata
 ```
 Note: When you remove containers from the Docker engine, any data that exists in the containers is destroyed. 

<hr>

## Run SnappyData on Docker Cloud

**NOTE:**
```
The latest Docker image has not been tested with Docker Cloud.
We recommend using Helm charts to launch SnappyData cluster on Kubernetes.
Please visit https://github.com/SnappyDataInc/spark-on-k8s/tree/master/charts/snappydata
```

Docker Cloud is Docker's official platform for building, managing and deploying Docker containers across a variety of Cloud providers. It also provides features ideal for development workflows.

To connect to the Cloud providers like AWS, AZURE and Digital Ocean refer to the official [Docker documentation](https://docs.docker.com/docker-cloud/infrastructure/link-aws/).

### Connect to Cloud Hosting Provider

Using Docker Cloud, connect to a cloud hosting provider of your choice. Currently, Amazon Web Services, Digital Ocean, Microsoft Azure, Softlayer and Packet and BYOH (bring your own host) are supported.

1. Go to the [Docker Cloud](http://cloud.docker.com) page, and log in using your Docker ID.

2. **Create a Node: **
 a. From the left-pane, click **Nodes**. The **Nodes** page is displayed.

 ![Node](images/nodes.png) 

 b. Click **Create** and provide the following information on the **Nodes Clusters / Wizard** page. 
 ![Node](images/create_node.png)
 
 c. Based on your selection, additional fields are displayed. Enter the required information, and click **Launch node cluster**.
 
 ![Node](images/create_node1.png) 
   
 d. It may take some time to create a node. The status is displayed as **Deploying**. When the node is created, the status is updated to **Deployed**.

3. **Create Stacks:**
 a. In the left pane, click **Stacks**. The **Stacks **page is displayed.

 ![Node](images/stacks.png) 
 
 b. Click **Create **. The **Stacks/Wizard** page is displayed.

 ![Node](images/create_stack.png) 
 
 c. Enter a name for the stack. 
 
 d. Copy and paste the sample code provided in the [**stack.yml **](https://raw.githubusercontent.com/SnappyDataInc/snappy-cloud-tools/master/docker/docker-cloud/stack.yml) file in the text box. This starts a locator, a server and a lead using the latest image provided by SnappyData.

 ![Node](images/create_stack2.png) 

 e. Click **Create** to create the stack or click **Create & Deploy** to create and deploy the stack. If you click **Create**, you have to manually start the stack after it is created.

 f. The status of the list of the resulting services is displayed.
 Currently, the default strategy (emptiest node) used by Docker Cloud is used for load balancing. Based on your requirements, you can use any of the the strategies provided by Docker.

 g. To verify the status of the elements, click on **Nodes**, select a node, and then go to the **Containers** tab. The page displays the containers that are running.

 ![Node](images/verify_containers.png) 

4. **Verify connection to the Snappy shell ** 
 a. [Download](http://snappydatainc.github.io/snappydata/install) the binary files from the SnappyData repository. Go the location of the **bin** directory in the SnappyData home directory, and then run the following command:

 ```
 $ bin/snappy
 SnappyData version 1.0.0 
 snappy>
 ```
  Note: You can also connect to SnappyData with DB client tools like dbSchema, DBVisualizer or Squirrel SQL client using the **snappydata-store-client-1.5.4.jar** file available on the official [SnappyData Release page](#https://github.com/SnappyDataInc/snappydata/releases). Refer to the documentation provided by your client tool for instructions on how to make a JDBC connection.
 
5. **Make a JDBC connection**

 a. Click on the node you want to connect to. Use the details of the connection string to connect to the locator from your local machine.

  ```
  $ snappy> connect client '<Your Machine IP>:1527';
  Using CONNECTION0
  snappy>
  ```
 b. Enter the following command followed by the URL of the JDBC connection.
 
  ```
  snappy> connect client <connection string>
  ```
  
 c. You can also monitor the cluster by connecting to the SnappyData UI using the URL.
![Node](images/monitor.png) 


NOTE: The above document provides you basic instructions to set up a cluster using Docker Cloud. Depending on your needs, you can explore the full potential of SnappyData on Docker Cloud using the UI or CLI. Refer to the [Docker Cloud's documentation](https://docs.docker.com/docker-cloud/) and the [SnappyData documentation](http://snappydatainc.github.io/snappydata/) for more information.

<hr>

## SnappyData With Docker Swarm

**NOTE:**
```
The latest Docker image has not been tested with Docker Swarm.
We recommend using Helm charts to launch SnappyData cluster on Kubernetes.
Please visit https://github.com/SnappyDataInc/spark-on-k8s/tree/master/charts/snappydata
```

This article explains how to setup multi-host SnappyData cluster using Docker Swarm, Docker Machine, and Docker Compose.

### Prerequisites
Before you begin, make sure you have a system on your network with the latest version of Docker Engine, Docker Machine and Docker Compose installed. The example also relies on VirtualBox. If you are using Mac or Windows with Docker Toolbox, you have all of these installed already.

**Step 1: Set up a key-value store**

An overlay network requires a key-value store. The key-value store holds information about the network state which includes discovery, networks, endpoints, IP addresses, and more. Docker supports Consul, Etcd, and ZooKeeper key-value stores. We will use Consul.

 a. Log into a system prepared with the prerequisite Docker Engine, Docker Machine, and VirtualBox software.

 b. Create virtual machine called mh-keystore

 ```
 $ docker-machine create -d virtualbox mh-keystore
 ```
 c. Set your local environment to the mh-keystore machine.

 ```
 $ eval "$(docker-machine env mh-keystore)"
 ```
 d. Start a  progrium/consul  container running  on the  mh-keystore  machine

 ```
 $ docker run -d -p "8500:8500" -h "consul" progrium/consul -server -bootstrap
 ```

**Step 2: Create a Swarm cluster**

 a. Create a Swarm master.

 ```
 $ docker-machine create \
    -d virtualbox \
    --virtualbox-memory 4096
    --swarm --swarm-master \
    --swarm-discovery="consul://$(docker-machine ip mh-keystore):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip mh-keystore):8500" \
    --engine-opt="cluster-advertise=eth1:2376" \
    snappy-swarm0
 ```

 b. Create two host and add it to the Swarm cluster.

 ```
 $ docker-machine create \
    -d virtualbox \
    --virtualbox-memory 4096
    --swarm \
    --swarm-discovery="consul://$(docker-machine ip mh-keystore):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip mh-keystore):8500" \
    --engine-opt="cluster-advertise=eth1:2376" \
    snappy-swarm1
 ```

 ```
 $ docker-machine create \
   -d virtualbox \
   --virtualbox-memory 4096
   --swarm \
   --swarm-discovery="consul://$(docker-machine ip mh-keystore):8500" \
   --engine-opt="cluster-store=consul://$(docker-machine ip mh-keystore):8500" \
   --engine-opt="cluster-advertise=eth1:2376" \
   snappy-swarm2
 ```

 c. List your machines to confirm they are all up and running.

 ```
 $ docker-machine ls
 NAME            ACTIVE   DRIVER       STATE     URL                         SWARM                    DOCKER    ERRORS
 mh-keystore     *        virtualbox   Running   tcp://192.168.99.100:2376                            v1.12.3
 snappy-swarm0   -        virtualbox   Running   tcp://192.168.99.104:2376   snappy-swarm0 (master)   v1.12.3
 snappy-swarm1   -        virtualbox   Running   tcp://192.168.99.105:2376   snappy-swarm0            v1.12.3
 snappy-swarm2   -        virtualbox   Running   tcp://192.168.99.106:2376   snappy-swarm0            v1.12.3
 ```

 At this point, you have a set of hosts running on your network. You are ready to create a multi-host network for containers using these hosts.
 Leave your terminal open and go onto the next step.

**Step 3: Copy SnappyData image in three machines**

 a. Pull the latest image of snappydata and save it in temp directory
 ```
 $ docker-machine ssh snappy-swarm0 'docker pull snappydatainc/snappydata;docker save -o /tmp/snappydata.tar snappydatainc/snappydata:latest'
 ```

 b. Copy image to other virtual machines 

 ```
 $ docker-machine scp snappy-swarm0:/tmp/snappydata.tar snappy-swarm1:/tmp/snappydata.tar
 $ docker-machine scp snappy-swarm0:/tmp/snappydata.tar snappy-swarm2:/tmp/snappydata.tar
 ```
 c. Load the image on virtual machines

 ```
 $ docker-machine ssh snappy-swarm1 "docker load -i /tmp/snappydata.tar"
 $ docker-machine ssh snappy-swarm2 "docker load -i /tmp/snappydata.tar"
 ```

**Step 4: Run SnappyData on Network**

 a. Point your environment to the Swarm master.

 ```
 $ eval $(docker-machine env --swarm snappy-swarm0)
 ```

 b. Use docker info to view swarm

 ```
 $ docker info
 Containers: 4
  Running: 4
  Paused: 0
  Stopped: 0
 Images: 6
 Server Version: swarm/1.2.5
 Role: primary
 Strategy: spread
 Filters: health, port, containerslots, dependency, affinity, constraint
 Nodes: 3
  snappy-swarm0: 192.168.99.104:2376
   └ ID: THKK:ZYSX:BSRW:XVT5:DWR7:JUVU:JW4M:TIWJ:OBYE:SD3O:SKVH:EXBG
   └ Status: Healthy
   └ Containers: 2 (2 Running, 0 Paused, 0 Stopped)
   └ Reserved CPUs: 0 / 1
   └ Reserved Memory: 0 B / 1.021 GiB
   └ Labels: kernelversion=4.4.27-boot2docker, operatingsystem=Boot2Docker 1.12.3 (TCL 7.2); HEAD : 7fc7575 - Thu Oct 27 17:23:17 UTC 2016, provider=virtualbox, storagedriver=aufs
   └ UpdatedAt: 2016-12-13T09:15:04Z
   └ ServerVersion: 1.12.3
  snappy-swarm1: 192.168.99.105:2376
   └ ID: CAXT:FMFA:42DW:U66A:YUO4:QHQF:PXQE:BNVE:CHLX:EVIT:LB32:RAHX
   └ Status: Healthy
   └ Containers: 1 (1 Running, 0 Paused, 0 Stopped)
   └ Reserved CPUs: 0 / 1
   └ Reserved Memory: 0 B / 1.021 GiB
   └ Labels: kernelversion=4.4.27-boot2docker, operatingsystem=Boot2Docker 1.12.3 (TCL 7.2); HEAD : 7fc7575 - Thu Oct 27 17:23:17 UTC 2016, provider=virtualbox, storagedriver=aufs
   └ UpdatedAt: 2016-12-13T09:15:21Z
   └ ServerVersion: 1.12.3
  snappy-swarm2: 192.168.99.106:2376
   └ ID: 73AX:EVEW:AW7X:3UYW:X6UE:DRVU:LQMC:R5AR:VMHV:GHP6:BZ6D:T5LH
   └ Status: Healthy
   └ Containers: 1 (1 Running, 0 Paused, 0 Stopped)
   └ Reserved CPUs: 0 / 1
   └ Reserved Memory: 0 B / 1.021 GiB
   └ Labels: kernelversion=4.4.27-boot2docker, operatingsystem=Boot2Docker 1.12.3 (TCL 7.2); HEAD : 7fc7575 - Thu Oct 27 17:23:17 UTC 2016, provider=virtualbox, storagedriver=aufs
   └ UpdatedAt: 2016-12-13T09:15:16Z
   └ ServerVersion: 1.12.3
 ```
From this information, you can see that you are running 3 nodes running on Swarm Master.

**Step 5: Run SnappyData on Swarm**

 a. Use below [docker-compose.yml](https://raw.githubusercontent.com/SnappyDataInc/snappy-cloud-tools/master/docker/docker-compose.yml) file.

 ```
 version: '2'
 services:
  locator1:
      image: snappydatainc/snappydata
      working_dir: /opt/snappydata/
      command: bash -c "/opt/snappydata/sbin/snappy-locators.sh start -peer-discovery-address=locator1 -client-bind-address=0.0.0.0 && tail -f /dev/null"  
      ports:
        - "1527:1527"
      expose:
        - "10334"
        - "1527"
  server1:
      image: snappydatainc/snappydata
      working_dir: /opt/snappydata/
      command: bash -c "sleep 10 && /opt/snappydata/sbin/snappy-servers.sh start -locators=locator1:10334 -client-bind-address=0.0.0.0 -client-port=1528 && tail -f /dev/null"
      expose:
        - "10334"
        - "1528"
      ports:
        - "1528:1528"
      depends_on:
        - "locator1"
  snappy-lead1:
      image: snappydatainc/snappydata
      working_dir: /opt/snappydata/
      command: bash -c "sleep 20 && /opt/snappydata/sbin/snappy-leads.sh start -locators=locator1:10334 && tail -f /dev/null"
      depends_on:
       - "server1"
      ports:
       - "5050:5050"
 ```

 b. Run the Docker-compose with **docker-compose.yml** file

 ```
 $ docker-compose -f docker-compose.yml up -d
 Creating network "default" with the default driver
 Creating locator1_1
 Creating server1_1
 Creating snappy-lead1_1
 ```

 c. Verify the compose process

 ```
 $ docker-compose ps
 Name                       Command               State                                             Ports
 -----------------------------------------------------------------------------------------------------------------------------------------------------------
 locator1_1       bash -c /opt/snappydata/sb ...   Up      10334/tcp, 192.168.99.105:1527->1527/tcp, 1528/tcp, 5050/tcp, 7320/tcp, 8080/tcp
 server1_1        bash -c sleep 10 && /opt/s ...   Up      10334/tcp, 192.168.99.106:1527->1527/tcp, 1528/tcp, 5050/tcp, 7320/tcp, 8080/tcp
 snappy-lead1_1   bash -c sleep 20 && /opt/s ...   Up      10334/tcp, 1527/tcp, 1528/tcp, 192.168.99.104:5050->5050/tcp, 7320/tcp, 8080/tcp
 ```
 Within few seconds cluster is started.

<hr>

## Using Kubernetes

Kubernetes is a container orchestration platform that you can use to manage and scale your running containers across multiple instances or within a hybrid-cloud environment.

To know more about launching SnappyData cluster on Kubernetes, check out our [Helm charts](https://github.com/SnappyDataInc/spark-on-k8s/tree/master/charts/snappydata).

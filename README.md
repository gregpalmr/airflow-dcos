# airflow-dcos

## Apache Airflow 1.8.0 running on Mesosphere's Data Center Operating System (DC/OS) version 1.13.x.

This project contains DC/OS Metronome and Marathon JSON specifications that launch the Apache Airflow DAG scheduler on a DC/OS cluster. It utilizes a Docker container image that includes the Airflow application components as well as the Mesos native libaries and Python Eggs for Mesos. Therefore, you do NOT have to preinstall Apache Airflow on each DC/OS agent node. Also, the Airflow MesosExecutor class has been modified to use a Docker container image to host the DAG tasks. It is recommended that you modify the default Docker image and add your DAG tasks' artifacts to the image and then specify that new image as the image to use when launching your DAG tasks (see the description of USE_DOCKER_CONTAINER and DEFAULT_DOCKER_CONTAINER_IMAGE below).

Contents:

     marathon/airflow-postgresql-marathon.json	- Start a Postgres instance for Airflow to use to store job info
     marathon/airflow-scheduler-marathon.json	- Start the Airflow DAG Scheduler
     marathon/airflow-webserver-marathon.json	- Start the Airflow Web console

     jobs/airflow-initdb-job.json			- Launch the Airflow "initdb" process to create database tables
     jobs/airflow-resetdb-job.json			- (optionally) Launch the Airflow "resetdb" process
     jobs/airflow-submit-tutorial-dag-job.json	- Launch an example DAG job

# USAGE

### Clone this repo on your client computer

     $ git clone https://github.com/gregpalmr/airflow-dcos

     $ cd airflow-dcos

### 1. Launch a DC/OS cluster with at least 3 private agent nodes and 1 public agent node.

### 2. Install Marathon-LB load balancer or Edge-LB on your DC/OS cluster 

These instructions show how to use Marathon-LB. If you are using the Enterprise version of DC/OS, you should configure M-LB to use a service account. Instructions on how to install Marathon-LB with a service account can be found here:

     https://docs.mesosphere.com/services/marathon-lb

For open source DC/OS use the "Universe" DC/OS dashboard page to lauch the Marathon-LB service, or use the command line interface (CLI) with the command:

     $ dcos package install marathon-lb --yes

### 3. Start the Airflow Postgres database instance using the CLI 

If you would like to change the database username or password, change the environment variables included in the json file named marathon/airflow-postgresql-marathon.json. Change the following two environment variables:

         "POSTGRES_USER": "airflow",
         "POSTGRES_PASSWORD": "changeme"

If you DON'T want to expose the Postgres network listener to anyone outside the cluster (it is not required for Airflow to operate successfully), you can remove the following line from the marathon/airflow-postgresql-marathon.json file:

         "HAPROXY_GROUP": "external"

Then run the following CLI command to start the Airflow Postgres instance:

     $ dcos marathon app add marathon/airflow-postgresql-marathon.json

To test test the Postgres instance running on DC/OS, you can install the psql command on MacOS using the command:

     $ brew install postgresql

Once the Airflow Postgres instance is running on DC/OS, you can test a connection to it using a locally install psql command:

     $ psql -d airflow-db -U airflow -W -p 15432 -h <ip address of public agent>

     NOTE: If it fails to connect, make sure your AWS Security Group inbound rules allow port 15432, 
     or your other cloud vendor's firewall rules allow port 15432.

### 4. Launch the Airflow "initdb" job to create the database schema 

If you changed the database username or password, then include the new settings in the environment variables in this json file.

         "POSTGRES_USER": "<new user name>",
         "POSTGRES_PASSWORD": "<new password>"

Then run the following CLI commands:

     $ dcos job add jobs/airflow-initdb-job.json

     $ dcos job run airflow-initdb-job

### 5. Start the Airflow DAG Scheduler

If you changed the database username or password, then include the new settings in the environment variables in this json file.

         "POSTGRES_USER": "<new user name>",
         "POSTGRES_PASSWORD": "<new password>"

You can also change the Airflow DAG scheduler Mesos tunables to match your cluster size. Change these environment variables:

		"ENABLE_DEBUG_LOG": "true",
		"TASK_CPU": "1",
		"TASK_MEMORY": "1024",
		"PARALLELISM": "32",
		"DAG_CONCURRENCY": "16",
		"MAX_ACTIVE_RUNS_PER_DAG": "16",

If you have your own Docker container image (recommended), then you can specify it by changing these environment variables:

    "USE_DOCKER_CONTAINER": "True",
    "DEFAULT_DOCKER_CONTAINER_IMAGE": "gregpalmermesosphere/airflow-dcos:latest",

Then run the following CLI commands:

     $ dcos marathon app add marathon/airflow-scheduler-marathon.json

### 6. Start the Airflow Web console

If you changed the database username or password, then include the new settings in the environment variables in this json file.

         "POSTGRES_USER": "<new user name>",
         "POSTGRES_PASSWORD": "<new password>"

Then run the following CLI commands:

     $ dcos marathon app add marathon/airflow-webserver-marathon.json

Once the Web console app is running, you can view the console via the Marathon-LB service port at:

     http://<ip address of public agent>:14300
     
### 7. Launch an example DAG job:

    If you changed the database username or password, then include the new settings in the environment variables in this json file.

         "POSTGRES_USER": "<new user name>",
         "POSTGRES_PASSWORD": "<new password>"

    Then run the following CLI commands:

        $ dcos job add jobs/airflow-submit-tutorial-dag-job.json

        $ dcos job run airflow-submit-tutorial-dag-job

Once the example DAG job is running, you can view the progress on the Airflow Web console by clicking on the "tutorial" DAG listed on the "DAGs" page.

### 8. You can optionally reset the Airflow Postgres database schema (erasing all previous data) by running this DC/OS job:

     $ dcos job add jobs/airflow-resetdb-job.json

     $ dcos job run airflow-resetdb-job

### 9. Two scripts are provided to start and stop the Airflow services in DC/OS. Use these commands:

     $ scripts/start-af.sh

     $ scripts/stop-af.sh

### TODO:

A. Combine the Airflow Scheduler task with the Airflow Websever task using DC/OS Pod support (mulitple containers sharing a mounted volume), so that they can "see" new airflow DAG scheduler requests created by end-users.

B. Add instructions on how to launch Airflow in DC/OS Cluster STRICT mode.

C. Deploy these Airflow tasks using Mesosphere's Service Development Kit or SDK (see https://mesosphere.github.io/dcos-commons).

D. Upgrade the version of Airflow to 1.10. This will require modification of the Airflow Python source code for the Airflow Mesos executor (./airflow/contrib/executors/mesos_executor.py)



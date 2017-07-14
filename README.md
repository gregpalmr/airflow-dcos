# airflow-dcos
Apache Airflow running on Mesosphere's Data Center Operating System (DC/OS)

This project contains DC/OS Metronome and Marathon JSON specifications that launch the Apache Airflow DAG scheduler on a DC/OS cluster.

Contents:

     marathon/airflow-postgresql-marathon.json	- Start a Postgres instance for Airflow to use to store job info
     marathon/airflow-scheduler-marathon.json	- Start the Airflow DAG Scheduler
     marathon/airflow-webserver-marathon.json	- Start the Airflow Web console

     jobs/airflow-initdb-job.json				- Launch the Airflow "initdb" process to create database tables
     jobs/airflow-resetdb-job.json				- (optionally) Launch the Airflow "resetdb" process
     jobs/airflow-submit-tutorial-dag-job.json	- Launch an example DAG job

`USAGE`

1. Clone this repo on your client computer

     $ git clone https://github.com/gregpalmr/airflow-dcos
     $ cd airflow-dcos

1. Launch a DC/OS cluster with at least 3 private agent nodes and 1 public agent node.

2. Install Marathon-LB on your DC/OS cluster. If you are using the Enterprise version of DC/OS, you should configure M-LB to use a service account. For open source DC/OS use the "Universe" DC/OS dashboard page to lauch the Marathon-LB service, or use the command line interface (CLI) with the command:

     $ dcos package install marathon-lb --yes

3. Start the Airflow Postgres database instance using the CLI:

     $ dcos marathon app add marathon/airflow-postgresql-marathon.json

Once the Postgres instance is running, you can test a connection to it using a locally install psql command:

     $ psql -d airflow-db -U airflow -W -p 15432 -h <ip address of public agent>

4. Launch the Airflow "initdb" job to create the database schema:

     $ dcos job add jobs/airflow-initdb-job.json
     $ dcos job run airflow-initdb-job

5. Start the Airflow DAG Scheduler

     $ dcos marathon app add marathon/airflow-scheduler-marathon.json

6. Start the Airflow Web console

     $ dcos marathon app add marathon/airflow-webserver-marathon.json

Once the Web console app is running, you can view the console via the Marathon-LB service port at:

     http://<ip address of public agent>:14300
     
7. Launch an example DAG job:

    $ dcos job add jobs/airflow-submit-tutorial-dag-job.json
    $ dcos job run airflow-submit-tutorial-dag-job

Once the example DAG job is running, you can view the progress on the Airflow Web console by clicking on the "tutorial" DAG listed on the "DAGs" page.

8. You can optionally reset the Airflow Postgres database schema (erasing all previous data) by running this DC/OS job:

     $ dcos job add jobs/airflow-resetdb-job.json
     $ dcos job run airflow-resetdb-job



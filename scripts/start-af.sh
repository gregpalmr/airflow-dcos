#!/bin/bash
#
# SCRIPT: start-af.sh
#
# Use this script to start the Airflow package on DC/OS 
#

echo

# Check if the DC/OS CLI command is installed
result=$(which dcos)
if [ "$result" == "" ]
then
    echo ""
    echo " ERROR: The DC/OS CLI command binary is not installed. Please install it. "
    echo ""
    exit 1
fi

# Check if the CLI is logged in
result=$(dcos node 2>&1)
if [[ "$result" == *"No cluster is attached"* ]]
then
    echo
    echo " ERROR: No cluster is attached. Please use the 'dcos cluster attach' command "
    echo " or use the 'dcos cluster setup' command."
    echo " Exiting."
    echo
    exit 1
fi

if [[ "$result" == *"Authentication failed"* ]]
then
    echo
    echo " ERROR: Not logged in. Please log into the DC/OS cluster with the "
    echo " command 'dcos auth login'"
    echo " Exiting."
    echo
    exit 1
fi

# Check if the DC/OS CLI command is working against a working cluster
result=$(dcos node 2>&1)
if [[ "$result" == *"is unreachable"* ]]
then
    echo ""
    echo " ERROR: DC/OS Master Node is unreachable. Is the DC/OS CLI configured correctly"
    echo ""
    echo "        Run:   dcos cluster setup <master node ip>"
    exit 1
fi

# Install the Enterprise CLI (if available) so we can create service account users and secrets
echo " Installing dcos-enterprise-cli package "
dcos package install --cli dcos-enterprise-cli --yes > /dev/null 2>&1

if [ $? != 0 ]
then
    echo
    echo " Unable to install the Enterprise CLI, continuing without it."
    echo
    enteprise_cli="false"
else
    enteprise_cli="true"
fi

if [ "$enteprise_cli" == "true" ]
then
    # Create the service account user for the airflow tasks 
    echo
    echo " Creating SSL Cert and Service Account User for Airflow tasks"
    rm -rf /tmp/private-key0.pem /tmp/public-key0.pem > /dev/null 2>&1
    dcos security org service-accounts keypair /tmp/private-key0.pem /tmp/public-key0.pem
    dcos security org service-accounts create -p /tmp/public-key0.pem -d 'Airflow service account' airflow
    dcos security secrets create-sa-secret /tmp/private-key0.pem airflow airflow/sa

    # Create the access control list privs for the airflow service account
    echo
    echo " Adding privilages to service account user the \"airflow\" user"
    dcos security org users grant airflow  dcos:mesos:master:framework:role:airflow-role create
    dcos security org users grant airflow  dcos:mesos:master:task:user:root create
    dcos security org users grant airflow  dcos:mesos:agent:task:user:root create
    dcos security org users grant airflow  dcos:mesos:master:reservation:role:airflow-role create
    dcos security org users grant airflow  dcos:mesos:master:reservation:principal:airflow delete
    dcos security org users grant airflow  dcos:mesos:master:volume:role:airflow-role create
    dcos security org users grant airflow  dcos:mesos:master:volume:principal:airflow delete
    dcos security org users grant airflow  dcos:secrets:default:/airflow/* full
    dcos security org users grant airflow  dcos:secrets:list:default:/airflow read
    dcos security org users grant airflow  dcos:adminrouter:ops:ca:rw full
    dcos security org users grant airflow  dcos:adminrouter:ops:ca:ro full
    dcos security org users grant airflow  dcos:mesos:master:framework:role:slave_public/airflow-role create
    dcos security org users grant airflow  dcos:mesos:master:framework:role:slave_public/airflow-role read
    dcos security org users grant airflow  dcos:mesos:master:reservation:role:slave_public/airflow-role create
    dcos security org users grant airflow  dcos:mesos:master:volume:role:slave_public/airflow-role create
    dcos security org users grant airflow  dcos:mesos:master:framework:role:slave_public read
    dcos security org users grant airflow  dcos:mesos:agent:framework:role:slave_public read
fi

# Start the Airflow Postgresql service

echo
echo " Starting the Airflow Postgresql Service "
echo

dcos marathon app add marathon/airflow-postgresql-marathon.json > /dev/null 2>&1

while true
do
    # get the task list and see if the airflow-postgresql task is running
    task_list=$(dcos task | grep postgresql | wc -l)

    if [ "$task_list" -gt 0 ]
    then

        task_status=$(dcos task | grep postgresql | awk '{print $4}')

        if [ "$task_status" != "R" ]
        then
            printf "."
        else
            echo " "
            echo " Airflow Postgresql service is running."
            break
        fi
    else
        printf "."
    fi
    sleep 5
done

echo
echo " Starting the Airflow InitDB process"
echo

dcos job add jobs/airflow-initdb-job.json > /dev/null 2>&1
printf " ."
sleep 3
job_id=$(dcos job run airflow-initdb-job | awk '{print $3}')

printf "."

task_started="false"

while true
do
    # get the task list and see if the airflow-initdb-job task is running
    task_list=$(dcos job history airflow-initdb-job | grep $job_id | wc -l)

    if [ "$task_started" == "false" ] && [ "$task_list" -gt 0 ]
    then
        task_started="true"
    else
        if [ "$task_started" == "false" ]
        then
            printf "."
        fi
    fi

    if [ "$task_started" == "true" ]
    then
        task_list=$(dcos task | grep airflow-initdb-job | wc -l)

        if [ "$task_list" -gt 0 ]
        then
            printf "."
        else
            echo " "
            echo " "
            echo " Airflow InitDB process is complete"
            break
        fi
    else
        printf "."
    fi
    sleep 5
done

echo
echo " Running the Airflow DAG Scheduler task"
echo

dcos marathon app add marathon/airflow-scheduler-marathon.json > /dev/null 2>&1
printf " "
while true
do
    # get the task list and see if the airflow-postgresql task is running
    task_list=$(dcos task | grep airflow-scheduler | wc -l)

    if [ "$task_list" -gt 0 ]
    then

        task_status=$(dcos task | grep airflow-scheduler | awk '{print $4}')

        if [ "$task_status" != "R" ]
        then
            printf "."
        else
            echo " "
            echo " "
            echo " Airflow DAG Scheduler service is running"
            break
        fi
    else
        printf "."
    fi
    sleep 5
done

echo
echo " Running the Airflow Webserver task"
echo

dcos marathon app add marathon/airflow-webserver-marathon.json > /dev/null 2>&1

printf " "
while true
do
    # get the task list and see if the airflow-postgresql task is running
    task_list=$(dcos task | grep airflow-webserver | wc -l)

    if [ "$task_list" -gt 0 ]
    then

        task_status=$(dcos task | grep airflow-webserver | awk '{print $4}')

        if [ "$task_status" != "R" ]
        then
            printf "."
        else
            echo " "
            echo " "
            echo " Airflow Web Server is running."
            break
        fi
    else
        printf "."
    fi
    sleep 5
done

echo
echo "Done."

echo
echo " To submit an example Airflow DAG job, run the following CLI commands:"
echo
echo "   \$ dcos job add jobs/airflow-submit-tutorial-dag-job.json"
echo
echo "   \$ dcos job run airflow-submit-tutorial-dag-job"
echo

# end of script

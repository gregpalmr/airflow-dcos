#
# SCRIPT: stop-af.sh
#

CORE_DCOS_URL=$(dcos config show core.dcos_url 2>&1)

if [[ $CORE_DCOS_URL == *"http"* ]]
then
    echo ""
else
    echo
    echo "     ERROR: core.dcos_url not found. Exiting."
    exit 1
fi

# Install the Enterprise CLI (if available) so we can create service account users and secrets
echo
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

echo
echo " Removing Job: \"airflow-initdb-job\""
dcos job remove "airflow-initdb-job" > /dev/null 2>&1

echo
echo " Removing Job: \"airflow-submit-tutorial-dag-job\""
sleep 2
dcos job remove "airflow-submit-tutorial-dag-job" --stop-current-job-runs > /dev/null 2>&1

echo
echo " Destroying Airflow Webserver service"
dcos marathon app remove --force "airflow/airflow-webserver"
sleep 2

echo
echo " Destroying Airflow DAG Scheduler service"
dcos marathon app remove --force "airflow/airflow-scheduler"
sleep 2

echo
echo " Destroying Airflow Postgresql service"
dcos marathon app remove --force "airflow/airflow-postgresql"
sleep 2

dcos marathon group remove --force "airflow"


if [ "$enteprise_cli" == "true" ]
then
    # Destroy the service account user for the airflow tasks
    echo
    echo " Removing service account user: airflow"
    dcos security secrets delete  airflow/sa > /dev/null 2>&1
    dcos security org service-accounts delete airflow > /dev/null 2>&1
fi

echo 
echo "Done."

# End of script

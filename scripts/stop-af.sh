#
# SCRIPT: stop-af.sh
#

CORE_DCOS_URL=$(dcos config show core.dcos_url 2>&1)

if [[ $CORE_DCOS_URL == *"http"* ]]
then
    echo "     core.dcos_url found."
else
    echo "     ERROR: core.dcos_url not found. Exiting."
    exit 1
fi

echo
echo " Destroying Airflow Webserver service"
echo
dcos marathon app remove --force "airflow/airflow-webserver"
sleep 2

echo
echo " Destroying Airflow DAG Scheduler service"
echo
dcos marathon app remove --force "airflow/airflow-scheduler"
sleep 2

echo
echo " Destroying Airflow Postgresql service"
echo
dcos marathon app remove --force "airflow/airflow-postgresql"
sleep 2

dcos marathon group remove --force "airflow"

echo
echo " Removing Job: \"airflow-initdb-job\""
echo
dcos job remove "airflow-initdb-job" > /dev/null 2>&1

echo
echo " Removing Job: \"airflow-submit-tutorial-dag-job\""
echo
dcos job remove "airflow-submit-tutorial-dag-job" > /dev/null 2>&1

# End of script

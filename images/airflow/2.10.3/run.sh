#!/bin/bash
set -e

# Sync DAGs before running docker compose
SOURCE_DAGS="../../../../dart/airflow/dags"
TARGET_DAGS="./dags"

# Sync dbt project files
SOURCE_DBT="../../../../dart/dbt/core"
TARGET_DBT="./dags/dbt/core"

echo "Checking for DAG folder at: $SOURCE_DAGS"
if [ -d "$SOURCE_DAGS" ]; then
    echo "Syncing DAGs from $SOURCE_DAGS → $TARGET_DAGS ..."
    rsync -a --delete "$SOURCE_DAGS/" "$TARGET_DAGS/"
    echo "DAG sync completed."
else
    echo "No DAG folder found at $SOURCE_DAGS — skipping DAG sync."
fi

echo "Checking for dbt project at: $SOURCE_DBT"
if [ -d "$SOURCE_DBT" ]; then
    echo "Syncing dbt project from $SOURCE_DBT → $TARGET_DBT ..."
    mkdir -p "$TARGET_DBT"
    rsync -a --delete "$SOURCE_DBT/" "$TARGET_DBT/"
    echo "dbt sync completed."
else
    echo "No dbt project found at $SOURCE_DBT — skipping dbt sync."
fi

COMMAND=$1

# Check if 'podman' or 'finch' is available, otherwise use 'docker'
if command -v finch &> /dev/null; then
    CONTAINER_RUNTIME="finch"
elif command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
else
    CONTAINER_RUNTIME="docker"
fi

# Generate valid Fernet key as json
generate_fernet_key() {

    # Install cryptography package quietly
    chmod +x temporary-pip-install generate_fernet_key.py
    ./temporary-pip-install cryptography >/dev/null 2>&1
    
    # Generate the key and format as JSON
    KEY=$(python3 generate_fernet_key.py)
    
    # Uninstall cryptography package quietly
    python3 -m pip uninstall -y cryptography cryptography-vectors &>/dev/null 2>&1
    
    echo "$KEY"
}

# Set up cache directory ; generate if it dosen't exist
CACHE_DIR="${HOME}/.cache/mwaa-local"
FERNET_KEY_FILE="${CACHE_DIR}/fernet.key"
mkdir -p "${CACHE_DIR}"

# Check if we have a cached Fernet key, if not generate and cache it
if [ ! -f "${FERNET_KEY_FILE}" ]; then
    generate_fernet_key > "${FERNET_KEY_FILE}"
    chmod 600 "${FERNET_KEY_FILE}"
fi

# Read the Fernet key from cache
FERNET_KEY=$(cat "${FERNET_KEY_FILE}")
export FERNET_KEY
BUILDARCH=$(uname -m)
if [ "$BUILDARCH" = "x86_64" ]; then
    BUILDARCH="amd64"
elif [ "$BUILDARCH" = "aarch64" ]; then
    BUILDARCH="arm64"
fi
export BUILDARCH
echo "Detected build architecture: $BUILDARCH"

# Create required directories for Docker volume mounts
mkdir -p ./logs/airflow
# Build the Docker image
./build.sh $CONTAINER_RUNTIME

ACCOUNT_ID="" # Put your account ID here.
# ENV_NAME="" # Choose an environment name here.
REGION="us-west-2" # Keeping the region us-west-2 as default.

# AWS Credentials
if [ "$COMMAND" == "--CONNECT_TO_RDS_PROXY" ]; then
    eval "$(aws configure export-credentials --format env)"
else
    export AWS_ACCESS_KEY_ID="test"
    export AWS_SECRET_ACCESS_KEY="test"
    export AWS_SESSION_TOKEN="test"
fi

# BOM Generation
GENERATE_BILL_OF_MATERIALS="False"
export GENERATE_BILL_OF_MATERIALS

# MWAA Configuration
MWAA__CORE__REQUIREMENTS_PATH="/usr/local/airflow/requirements/requirements.txt"
MWAA__CORE__STARTUP_SCRIPT_PATH="/usr/local/airflow/startup/startup.sh"
MWAA__LOGGING__AIRFLOW_DAGPROCESSOR_LOGS_ENABLED="true"
#MWAA__LOGGING__AIRFLOW_DAGPROCESSOR_LOG_GROUP_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${ENV_NAME}-DAGProcessing"
MWAA__LOGGING__AIRFLOW_DAGPROCESSOR_LOG_LEVEL="INFO"
MWAA__LOGGING__AIRFLOW_SCHEDULER_LOGS_ENABLED="true"
#MWAA__LOGGING__AIRFLOW_SCHEDULER_LOG_GROUP_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${ENV_NAME}-Scheduler"
MWAA__LOGGING__AIRFLOW_SCHEDULER_LOG_LEVEL="INFO"
MWAA__LOGGING__AIRFLOW_TASK_LOGS_ENABLED="true"
#MWAA__LOGGING__AIRFLOW_TASK_LOG_GROUP_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${ENV_NAME}-Task"
MWAA__LOGGING__AIRFLOW_TASK_LOG_LEVEL="INFO"
MWAA__LOGGING__AIRFLOW_TRIGGERER_LOGS_ENABLED="true"
#MWAA__LOGGING__AIRFLOW_TRIGGERER_LOG_GROUP_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${ENV_NAME}-Scheduler"
MWAA__LOGGING__AIRFLOW_TRIGGERER_LOG_LEVEL="INFO"
MWAA__LOGGING__AIRFLOW_WEBSERVER_LOGS_ENABLED="true"
#MWAA__LOGGING__AIRFLOW_WEBSERVER_LOG_GROUP_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${ENV_NAME}-WebServer"
MWAA__LOGGING__AIRFLOW_WEBSERVER_LOG_LEVEL="INFO"
MWAA__LOGGING__AIRFLOW_WORKER_LOGS_ENABLED="true"
#MWAA__LOGGING__AIRFLOW_WORKER_LOG_GROUP_ARN="arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${ENV_NAME}-Worker"
MWAA__LOGGING__AIRFLOW_WORKER_LOG_LEVEL="INFO"
MWAA__CORE__TASK_MONITORING_ENABLED="false"
MWAA__CORE__TERMINATE_IF_IDLE="false"
MWAA__CORE__MWAA_SIGNAL_HANDLING_ENABLED="false"
export MWAA__CORE__REQUIREMENTS_PATH
export MWAA__CORE__STARTUP_SCRIPT_PATH
export MWAA__LOGGING__AIRFLOW_DAGPROCESSOR_LOGS_ENABLED
export MWAA__LOGGING__AIRFLOW_DAGPROCESSOR_LOG_GROUP_ARN
export MWAA__LOGGING__AIRFLOW_DAGPROCESSOR_LOG_LEVEL
export MWAA__LOGGING__AIRFLOW_SCHEDULER_LOGS_ENABLED
export MWAA__LOGGING__AIRFLOW_SCHEDULER_LOG_GROUP_ARN
export MWAA__LOGGING__AIRFLOW_SCHEDULER_LOG_LEVEL
export MWAA__LOGGING__AIRFLOW_TASK_LOGS_ENABLED
export MWAA__LOGGING__AIRFLOW_TASK_LOG_GROUP_ARN
export MWAA__LOGGING__AIRFLOW_TASK_LOG_LEVEL
export MWAA__LOGGING__AIRFLOW_TRIGGERER_LOGS_ENABLED
export MWAA__LOGGING__AIRFLOW_TRIGGERER_LOG_GROUP_ARN
export MWAA__LOGGING__AIRFLOW_TRIGGERER_LOG_LEVEL
export MWAA__LOGGING__AIRFLOW_WEBSERVER_LOGS_ENABLED
export MWAA__LOGGING__AIRFLOW_WEBSERVER_LOG_GROUP_ARN
export MWAA__LOGGING__AIRFLOW_WEBSERVER_LOG_LEVEL
export MWAA__LOGGING__AIRFLOW_WORKER_LOGS_ENABLED
export MWAA__LOGGING__AIRFLOW_WORKER_LOG_GROUP_ARN
export MWAA__LOGGING__AIRFLOW_WORKER_LOG_LEVEL
export MWAA__CORE__TASK_MONITORING_ENABLED
export MWAA__CORE__TERMINATE_IF_IDLE
export MWAA__CORE__MWAA_SIGNAL_HANDLING_ENABLED

if [ "$COMMAND" == "test-requirements" ] || [ "$COMMAND" == "test-startup-script" ]; then
    $CONTAINER_RUNTIME compose -f docker-compose-test-commands.yaml up "$COMMAND" --abort-on-container-exit
else
  if [ "$COMMAND" == "--CONNECT_TO_RDS_PROXY" ]; then
    CONNECT_TO_RDS_PROXY=true $CONTAINER_RUNTIME compose up
  else
    $CONTAINER_RUNTIME compose up
  fi
fi

#!/bin/bash

export ENVIRONMENT_STAGE="local"
echo "Airflow Environment is:" $ENVIRONMENT_STAGE

# --- IMPORT CONNECTIONS ---
CONNECTIONS_FILE="/usr/local/airflow/files/connections.json"
echo "Attempting to import connections from: ${CONNECTIONS_FILE}"
if [ -f "${CONNECTIONS_FILE}" ]; then
  # The 'airflow connections import' command reads the JSON and inserts/updates connections in the DB
  airflow connections import "${CONNECTIONS_FILE}"
  echo "Successfully imported connections."
else
  echo "Warning: Connections file not found at ${CONNECTIONS_FILE}. Skipping import."
fi

# --- IMPORT VARIABLES ---
VARIABLES_FILE="/usr/local/airflow/files/variables.json"
echo "Attempting to import variables from: ${VARIABLES_FILE}"
if [ -f "${VARIABLES_FILE}" ]; then
  # The 'airflow variables import' command reads the JSON and inserts/updates variables in the DB
  airflow variables import "${VARIABLES_FILE}"
  echo "Successfully imported variables."
else
  echo "Warning: Variables file not found at ${VARIABLES_FILE}. Skipping import."
fi

if [ "$CONNECT_TO_RDS_PROXY" = "true" ]; then
  echo "Connecting to RDS proxy via SSH..."
  
  # Extract RDS_HOST and SSH_ADDRESS from variables.json if they are not set
  if [ -z "$RDS_HOST" ] || [ -z "$SSH_ADDRESS" ]; then
    if [ -f "${VARIABLES_FILE}" ]; then
      echo "Extracting RDS_HOST and SSH_ADDRESS from ${VARIABLES_FILE}..."
      [ -z "$RDS_HOST" ] && RDS_HOST=$(python3 -c "import json; print(json.load(open('${VARIABLES_FILE}')).get('RDS_HOST', '').strip())")
      [ -z "$SSH_ADDRESS" ] && SSH_ADDRESS=$(python3 -c "import json; print(json.load(open('${VARIABLES_FILE}')).get('SSH_ADDRESS', '').strip())")
    fi
  fi

  SSH_KEY_PATH="/usr/local/airflow/files/keys/ssh_host.pem"

  echo "Debug: RDS_HOST='$RDS_HOST'"
  echo "Debug: SSH_ADDRESS='$SSH_ADDRESS'"
  echo "Debug: SSH_KEY_PATH='$SSH_KEY_PATH'"

  if [ -z "$RDS_HOST" ] || [ -z "$SSH_ADDRESS" ]; then
    echo "ERROR: RDS_HOST or SSH_ADDRESS is missing. Cannot establish SSH tunnel." >&2
  elif [ ! -f "$SSH_KEY_PATH" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY_PATH" >&2
  else
    echo "Establishing SSH tunnel: 5432:${RDS_HOST}:5432 via ${SSH_ADDRESS}"
    if ssh -4 -i "$SSH_KEY_PATH" -fNT -o ServerAliveInterval=60 -o ServerAliveCountMax=10 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -L 5432:${RDS_HOST}:5432 ${SSH_ADDRESS}; then
      echo "SSH tunnel to RDS proxy established."
    else
      echo "ERROR: Failed to establish SSH tunnel to RDS proxy. Exit code: $?" >&2
    fi
  fi
else
  echo "Skipping RDS proxy connection (CONNECT_TO_RDS_PROXY=${CONNECT_TO_RDS_PROXY:-false})."
fi
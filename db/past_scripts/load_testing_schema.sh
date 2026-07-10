#!/usr/bin/env bash

# ============================================================
# load_testing_schema.sh
#
# Public Safety Platform Database Loader
#
# Loads testing schema migrations 000-018
#
# ============================================================


set -euo pipefail


DATABASE="cad_testing"

SCHEMA_DIR="$(dirname "$0")/../schema/testing"


echo "============================================================"
echo " Loading CAD Testing Database Schema"
echo " Database: ${DATABASE}"
echo " Schema:   ${SCHEMA_DIR}"
echo "============================================================"


if ! command -v psql >/dev/null 2>&1
then
    echo "ERROR: psql not found"
    exit 1
fi


if [ ! -d "${SCHEMA_DIR}" ]
then
    echo "ERROR: Schema directory not found:"
    echo "${SCHEMA_DIR}"
    exit 1
fi



FILES=$(find "${SCHEMA_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.sql" \
    | sort)



if [ -z "${FILES}" ]
then
    echo "ERROR: No SQL migration files found"
    exit 1
fi



echo
echo "Migration files detected:"
echo "${FILES}"
echo



for FILE in ${FILES}
do

    NAME=$(basename "${FILE}")

    echo "============================================================"
    echo "Applying: ${NAME}"
    echo "============================================================"


    psql \
        --set ON_ERROR_STOP=1 \
        --dbname "${DATABASE}" \
        --file "${FILE}"


    echo
    echo "SUCCESS: ${NAME}"
    echo

done



echo "============================================================"
echo " Database migration completed successfully"
echo "============================================================"

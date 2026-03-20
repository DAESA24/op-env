#!/bin/bash
# Exec target for testing — reports its own environment
# Usage: check-env.sh [VAR_NAME ...]
# Prints EXEC_HAPPENED=true, then each requested var's value.

echo "EXEC_HAPPENED=true"
for var in "$@"; do
  echo "${var}=${!var:-UNSET}"
done
exit 0

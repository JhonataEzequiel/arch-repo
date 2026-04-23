#!/bin/bash
set -euo pipefail
declare -A choices

source lib/header.sh

keep_alive
check_prerequisites
update_mirrors
set_variables
choose_de
install_basic_features
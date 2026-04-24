#!/bin/bash
set -euo pipefail
declare -A choices
declare -a tte_options
declare -a terminal_options
declare -a terminal_utilities_options

source lib/header.sh

keep_alive
check_prerequisites
prepare_pacman
#update_mirrors
set_variables
choose_de
install_basic_features
terminal_emulator_setup
terminal_text_editor_setup
terminal_utilities_setup
install_zsh
shell_customizations
wine_setup
install_drivers
gaming_setup
configure_extra_setup

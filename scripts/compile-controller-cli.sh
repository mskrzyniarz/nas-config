#!/bin/bash
# This script creates a directory '/cli' in the chosen location, which will contain 
# a compiled version of the command-line tool (miskcoo/ugreen_leds_controller) 
# for managing the LED lights on the front panel of the UGREEN NAS
# 
# Usage:
#   ./compile-controller-cli.sh [-o|--output-dir <path>] [-b|--branch <branch>] [-w|--write-protocol <protocol>]
#
# Where:
#  -o|--output-dir <path>: The path where /cli directory containing the compiled CLI will be placed.
#                    By default, it will use the same directory as this script.
#
#  -b|--branch <branch>: The git branch of the miskcoo/ugreen_leds_controller repository to checkout.
#                        Defaults to 'master'.
#
#  -w|--write-protocol <protocol>: The write protocol to use with the CLI. Useful for testing different protocols.
#                                  If not specified, the CLI will use its default protocol. Setting this option with 'smbus-block' 
#                                  is required to make command-line tool work correctly with DXP4800 GT and iDX6011 (Pro).
#
# The script was prepared based on build-cli.sh script from tomatoandcake/ugreen-leds-truenas repository.
# Differences from the original script:
# - ability to specify a different branch of the miskcoo/ugreen_leds_controller repository
# - inside provided path I crate a directory /cli and place the compiled CLI there
# - creation of a temporary directory for the compilation process, which is deleted after the compilation is finished,
#   so data downloaded from the miskcoo/ugreen_leds_controller repository is not stored in the final /cli directory
# - runs tests to verify that the LED Controller CLI is working correctly after compilation
# - if /cli/ugreen_leds_cli is already present, it will be overwritten with the newly compiled version
#
# Here are URL to tomatoandcake/ugreen-leds-truenas repository:
# https://github.com/tomatoandcake/ugreen-leds-truenas
# That was used as a reference for this script.
#
# Here is URL to miskcoo/ugreen_leds_controller repository:
# https://github.com/miskcoo/ugreen_leds_controller
# That created the command-line tool for managing the LED lights on the front panel of the UGREEN NAS.
# Without his work, this script would not be possible.

set -euo pipefail

START_DIR="$(pwd)"
SCRIPT_ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_ROOT_DIR"
BRANCH_NAME="master"
WRITE_PROTOCOL=""
TMP_REPO_DIR="controller-tmp-repo"
CLI_TOOL_NAME="ugreen_leds_cli"
COMPILED_CLI_DIR="$SCRIPT_ROOT_DIR/$TMP_REPO_DIR/cli"
COMPILED_CLI="$COMPILED_CLI_DIR/$CLI_TOOL_NAME"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        -w|--write-protocol)
            WRITE_PROTOCOL="-write-protocol $2"
            shift 2
            ;;
    esac
done

function clear_controller_cli_tmp_repo {
    if [[ -d "$SCRIPT_ROOT_DIR/$TMP_REPO_DIR" ]]; then
        sudo rm -rf "$SCRIPT_ROOT_DIR/$TMP_REPO_DIR"
    fi
}

function cleanup {
    cd "$START_DIR"
    clear_controller_cli_tmp_repo
}

clear_controller_cli_tmp_repo

sudo git clone https://github.com/miskcoo/ugreen_leds_controller "$SCRIPT_ROOT_DIR/$TMP_REPO_DIR"

if [[ ! -f "$COMPILED_CLI_DIR/Makefile" ]]; then
    echo " "
    echo -e "\e[0;31mERROR: no Makefile found in the miskcoo/ugreen_leds_controller/cli repository\e[0m" >&2
    echo " "
    cleanup
    exit 1
fi

cd "$SCRIPT_ROOT_DIR/$TMP_REPO_DIR"

if ! git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
    echo " "
    echo -e "\e[0;31mERROR: the selected branch does not exist in the miskcoo/ugreen_leds_controller repository\e[0m" >&2
    echo " "
    cleanup
    exit 1
fi

git checkout "$BRANCH_NAME"

cd "$SCRIPT_ROOT_DIR"

sudo docker run --rm -v "$COMPILED_CLI_DIR":/src -w /src debian:bookworm \
  bash -c "apt-get update -qq && apt-get install -y -qq build-essential libi2c-dev && make"

if [[ ! -f "$COMPILED_CLI" ]]; then
    echo " "
    echo -e "\e[0;31mERROR: $CLI_TOOL_NAME was not compiled successfully\e[0m" >&2
    echo " "
    cleanup
    exit 1
fi

sudo chmod 755 "$COMPILED_CLI"

echo " "
echo -e "\e[0;32mSUCCESS: $CLI_TOOL_NAME was compiled successfully\e[0m" >&2
echo " "

echo "Simple test to verify that the LED Controller CLI is working correctly will be performed now."
echo "Step by step I will show you different LED light settings."

sudo modprobe i2c-dev

echo " "
echo "Test 1/8: All LEDs should be off"
sudo "$COMPILED_CLI" all $WRITE_PROTOCOL -off
read -p "Press enter to continue"

echo " "
echo "Test 2/8: The Power LED should be red"
sudo "$COMPILED_CLI" power $WRITE_PROTOCOL -on -color 255 0 0 -brightness 80
read -p "Press enter to continue"

echo " "
echo "Test 3/8: The LAN LED should be light blue"
sudo "$COMPILED_CLI" power $WRITE_PROTOCOL -off
sudo "$COMPILED_CLI" netdev $WRITE_PROTOCOL -on -color 0 255 255 -brightness 80
read -p "Press enter to continue"

echo " "
echo "Test 4/8: The Disk1 LED should be pink"
sudo "$COMPILED_CLI" netdev $WRITE_PROTOCOL -off
sudo "$COMPILED_CLI" disk1 $WRITE_PROTOCOL -on -color 255 0 255 -brightness 80
read -p "Press enter to continue"

echo " "
echo "Test 5/8: The Disk2 LED should be light green"
sudo "$COMPILED_CLI" disk1 $WRITE_PROTOCOL -off
sudo "$COMPILED_CLI" disk2 $WRITE_PROTOCOL -on -color 0 255 0 -brightness 80
read -p "Press enter to continue"

echo " "
echo "Test 6/8: The Disk3 LED should be yellow"
sudo "$COMPILED_CLI" disk2 $WRITE_PROTOCOL -off
sudo "$COMPILED_CLI" disk3 $WRITE_PROTOCOL -on -color 255 255 0 -brightness 80
read -p "Press enter to continue"

echo " "
echo "Test 7/8: The Disk4 LED should be white'"
sudo "$COMPILED_CLI" disk3 $WRITE_PROTOCOL -off
sudo "$COMPILED_CLI" disk4 $WRITE_PROTOCOL -on -color 255 255 255 -brightness 80
read -p "Press enter to continue"

echo " "
echo "Test 8/8: All LED lights should be blinking in different colors from left to right"
sudo "$COMPILED_CLI" disk4 $WRITE_PROTOCOL -off
sudo "$COMPILED_CLI" power $WRITE_PROTOCOL -on -color 255 0 255 -blink 400 600 -brightness 80
sleep 0.1
sudo "$COMPILED_CLI" netdev $WRITE_PROTOCOL -on -color 255 0 0 -blink 400 600 -brightness 80
sleep 0.1
sudo "$COMPILED_CLI" disk1 $WRITE_PROTOCOL -on -color 255 255 0 -blink 400 600 -brightness 80
sleep 0.1
sudo "$COMPILED_CLI" disk2 $WRITE_PROTOCOL -on -color 0 255 0 -blink 400 600 -brightness 80
sleep 0.1
sudo "$COMPILED_CLI" disk3 $WRITE_PROTOCOL -on -color 0 255 255 -blink 400 600 -brightness 80
sleep 0.1
sudo "$COMPILED_CLI" disk4 $WRITE_PROTOCOL -on -color 0 0 255 -blink 400 600 -brightness 80
read -p "Press enter to continue"

sudo "$COMPILED_CLI" all $WRITE_PROTOCOL -off
sudo "$COMPILED_CLI" power $WRITE_PROTOCOL -on -color 255 255 255 -brightness 50

TEST_PASSED=0
echo " "
echo "Did all tests pass and would you like to save the LED Controller CLI?"
select strictreply in "Yes" "No"; do
    relaxedreply=${strictreply:-$REPLY}
    case $relaxedreply in
        Yes | yes | Y | y ) TEST_PASSED=1; break;;
        No  | no  | N | n ) TEST_PASSED=0; break;;
    esac
done

if [ $TEST_PASSED -eq 0 ]; then
    cleanup
    echo " "
    echo -e "The LED Controller CLI file was not created." >&2
    echo -e "All temporary files have been deleted." >&2
    echo " "
fi

if [ $TEST_PASSED -eq 1 ]; then
    mkdir -p "$OUTPUT_DIR/cli"
    rm -f "$OUTPUT_DIR/cli/$CLI_TOOL_NAME"
    mv "$COMPILED_CLI" "$OUTPUT_DIR/cli/$CLI_TOOL_NAME"
    cleanup
    echo " "
    echo -e "\e[0;32mThe LED Controller CLI file was created successfully.\e[0m" >&2
    echo -e "\e[0;32mAll temporary files have been deleted.\e[0m" >&2
    echo -e "\e[0;32mThe compiled file '$CLI_TOOL_NAME' was saved in: '$SCRIPT_ROOT_DIR/cli'\e[0m" >&2
    echo " "
fi
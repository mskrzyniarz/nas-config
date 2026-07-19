[← Back to the main guide's steps](../README.md)

# UGREEN LED Controller support

**Table of Contents**   
[1. Introduction](#1-introduction)  
[2. Crate datasets that will contain the scripts](#2-crate-datasets-that-will-contain-the-scripts)  
[3. Download script to prepare command-line tool to control UGREEN LED lights](#3-download-script-to-prepare-command-line-tool-to-control-ugreen-led-lights)  
[4. Download LED Controller daemon script](#4-download-led-controller-daemon-script)  
[5. Start daemon when TrueNas boot](#5-start-daemon-when-truenas-boot)  
<br />
> [!NOTE]
> **Credits to:**
> - [**miskcoo**](https://github.com/miskcoo) as he made the [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller). Without his work, controlling LED lights would not be possible at all.
> - [**tomatoandcake**](https://github.com/tomatoandcake) as my instruction was prepared based of his solution from [tomatoandcake/ugreen-leds-truenas](https://github.com/tomatoandcake/ugreen-leds-truenas) repo.

### 1. Introduction

This file contain instruction how to get the [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) working on **UGREEN DXP4800 GT** with **TrueNAS**. \
If you follow it step by step, the whole thing should take less than about 5 minutes, you just copy and paste ready-made commands.

After completing all the steps, you'll have:
- Working LED lights on your UGREEN DXP4800 GT, informing you about the current LAN connection status and disk health. The daemon starts automatically when the TrueNAS system starts.

- only three files will be stored on you drive:
  - `./compile-controller-cli.sh`
  - `./ugreen-led-controller-daemon.sh`
  - `./cli/ugreen_leds_cl`

- a future-proof solution:

  - If you need to update the CLI to the UGREEN LED Controller, just run the `./compile-controller-cli.sh` script again (you can specify from which GIT branch the files to be compiled should be downloaded).

  - If for some reason you need to update or reinstall TrueNAS, simply add the daemon startup to Init Scripts in the TrueNAS settings (see [step 5](#5-start-daemon-when-truenas-boot) of this guide)

<br />

My solution is based mainly on [tomatoandcake's](https://github.com/tomatoandcake) code and ideas from his [ugreen-leds-truenas](https://github.com/tomatoandcake/ugreen-leds-truenas) project.

Main changes/additions compared to [tomatoandcake's solution](https://github.com/tomatoandcake/ugreen-leds-truenas):

- Differences in creating a CLI file for the LED Controller
  - Added the ability to select the location for creating the `/cli` directory containing the compiled CLI of [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) (argument: `[-o|--output-dir <path>]`).
  - Added the ability to compile [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) from different branch then `master` (argument: `[-b|--branch <branch>]`).  
  At the moment support of **UGREEN DXP4800 GT** is experimental and to make [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) work you must compile version from the `dev-idx601-series` branch.
  - After compiling the CLI file, a test is run where the user can check whether the controller is working correctly.
  - Added ability to select the `write-protocol` used by the [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) CLI (argument: `[-w|--write-protocol <protocol>]`).  
  This protocol is used in tests that run after generating the CLI file.  
  For the LED controller to work properly with **UGREEN DXP4800 GT**, you must pass the `-write-protocol` argument with the value `smbus-block` to the [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) CLI.

- Differences in the daemon script that sets the LED status:
  - Added ability to turn off night mode (feature that turns off all LEDs during a specified time window, default 11:00 PM to 7:00 AM) (argument: `[-n|--night-mode <true|false|0|1|on|off>]`).
  - Added ability to select path where the [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) CLI is placed (argument: `[-c|--cli-dir <path>]`).
  - Added ability to select the `write-protocol` used by the [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) CLI (argument: `[-w|--write-protocol <protocol>]`).  
  For the LED controller to work properly with **UGREEN DXP4800 GT**, you must pass the `-write-protocol` argument with the value `smbus-block` to the [UGREEN LED Controller](https://github.com/miskcoo/ugreen_leds_controller) CLI.
  - Changed LAN color when up - from `orange` to `blue`
  - Changed LAN color when all links down - from `red` to `orange`
  - LED light setting cycle interval changed - from `0.3s` to `0.5s`
  - Changed the interval for checking disk status, LAN state, SMART, schedule - from approx. `18s` to approx. `30s`

- More information about how each script works can be found in the comments to the script files:  
  [compile-controller-cli.sh](../scripts/compile-controller-cli.sh)  
  [ugreen-led-controller-daemon.sh](../scripts/ugreen-led-controller-daemon.sh)

## 2. Crate datasets that will contain the scripts

Create such structure of datasets:

Path: `/mnt/tank/configs/system/ugreen_leds_controller`  

Datasets structure:

```
tank [POOL]
    ├─ configs [DATASET]
        ├─ system [DATASETS]
            ├─ ugreen_leds_controller [DATASETS]
```

all datasets with `Apps` Dataset Preset.

:exclamation: **NOTE: You can use any location; just follow the instructions below and replace the path `/mnt/tank/configs/system/ugreen_leds_controller` with your own wherever it appears.** \
_I used this specific path solely because I have redundancy on the `tank` pool, and I store the config files for all my apps inside the `/mnt/tank/configs` dataset._

## 3. Download script to prepare command-line tool to control UGREEN LED lights

Open `System` / `Shell` page

In the shell, run the following commands one by one:

```bash
cd /mnt/tank/configs/system/ugreen_leds_controller
```
```bash
sudo curl -o compile-controller-cli.sh https://raw.githubusercontent.com/mskrzyniarz/nas-config/refs/heads/main/scripts/compile-controller-cli.sh
```

If you are curious what the script looks like, here is the link to [the compile-controller-cli.sh file](../scripts/compile-controller-cli.sh).

```bash
sudo chmod 755 compile-controller-cli.sh
```
```bash
sudo ./compile-controller-cli.sh --branch dev-idx601-series --write-protocol smbus-block
```
:exclamation: **IMPORTANT:
Passing arguments `--branch dev-idx601-series` and `--write-protocol smbus-block` \
are required to make it work with UGREEN DXP4800 GT as support for this model is still experimental.**


## 4. Download LED Controller daemon script

Open `System` / `Shell` page

In the shell, run the following commands one by one:

```bash
cd /mnt/tank/configs/system/ugreen_leds_controller
```

```bash
sudo curl -o ugreen-led-controller-daemon.sh https://raw.githubusercontent.com/mskrzyniarz/nas-config/refs/heads/main/scripts/ugreen-led-controller-daemon.sh
```

If you are curious what the script looks like, here is the link [to the ugreen-led-controller-daemon.sh file](../scripts/ugreen-led-controller-daemon.sh).

```bash
sudo chmod 755 ugreen-led-controller-daemon.sh
```

To test if LED Controller daemon works correctly, run one by one:
```bash
sudo modprobe i2c-dev
```

```bash
sudo ./ugreen-led-controller-daemon.sh --night-mode off --write-protocol smbus-block &
```

The script is running in the background. \
To test it, upload/download something, you can disconnect ethernet cable, etc. \
To stop it run:
```bash
sudo pkill -f ugreen-led-controller-daemon.sh
```

## 5. Start daemon when TrueNas boot

Open `System` / `Advanced Settings` page


- Inside the `Init/Shutdown Scripts` widget press the `Add` button and set:

    - `Type`: `Command`

    - `Command`:

        ```bash
        modprobe i2c-dev
        ```
    
    - `When`: `Pre Init`

    - `Enabled`: `checked`

    Press the `Save` button.

<br />

- Inside the `Init/Shutdown Scripts` widget press the `Add` button and set:

    - `Description`: `LED Controller Daemon`

    - `Type`: `Command`

    - `Command`:

        ```bash
        nohup bash /mnt/tank/configs/system/ugreen_leds_controller/ugreen-led-controller-daemon.sh --write-protocol smbus-block --night-mode off >/dev/null 2>&1 &
        ```
    
    - `When`: `Pre Init`

    - `Enabled`: `checked`

    Press the `Save` button.

<p align="right"><sub>____________</sub></p>
<p align="right">
  <a href="../truenas-setup/SMB_Configuration.md">Next step: SMB configuration →</a>
</p>

#!/bin/bash
#
# UGREEN DXP4800 GT — LED status daemon for TrueNAS SCALE
# ---------------------------------------------------------
# Userspace daemon (no kernel module). Run via Post Init "Command".
#
#   - Healthy disk      : solid green
#   - Disk I/O activity  : brief dark blink (UGOS-style)
#   - Disk fault/SMART   : solid red (blinking if pool degraded/faulted)
#   - Power LED          : solid white (red if any pool not ONLINE)
#   - LAN (netdev) LED   : orange when up, dark blink on traffic, red if down
#   - Off window         : all LEDs off (default 9:30pm-7am)
#
# Auto-detects populated bays via HCTL mapping (X:0:0:0 -> diskX+1) and all
# physical NICs (device symlink present, non-wireless).
#
# Tested target: TrueNAS SCALE 25.10.x, DXP4800 GT.
#
# Pre-requisites:
#   - i2c-dev kernel module (modprobe i2c-dev)
#   - precompiled version ugreen_leds_cli command-line tool should be placed 
#     in the same directory as this script, or in a subdirectory named "cli".
#
# Usage:
#   To start the daemon in the background use:
#     sudo modprobe i2c-dev
#     sudo ./ugreen-led-controller-daemon.sh [-c|--cli-dir <path>] [-w|--write-protocol <protocol>] [--night-mode off] &
#
#   To stop the daemon use:
#     sudo pkill -f ugreen-led-controller-daemon.sh
#
# Where:
#  -c|--cli-dir <path>: The path where the ugreen-leds-cli command-line tool is placed.
#                    By default, it will look for it in the same directory as this script.
#
#  -n|--night-mode <true|false|0|1|on|off>: If specified, it will enable or disable night mode.
#                    Night mode is a feature that turns off all LEDs during a specified time window 
#                    (default 11:00 PM to 7:00 AM). If not specified, night mode will be enabled by default.
#
#  -w|--write-protocol <protocol>: The write protocol to use with the CLI.
#                    If not specified, the CLI will use its default protocol. Setting this option with 'smbus-block' 
#                    is required to make LED Controller command-line tool work correctly with DXP4800 GT and iDX6011 (Pro).

set -uo pipefail

### ─────────────────────────── CONFIG ───────────────────────────

SCRIPT_ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI_TOOL_NAME="ugreen_leds_cli"
WRITE_PROTOCOL=""
NIGHT_MODE_ON=true

CLI="${SCRIPT_ROOT_DIR}/cli/${CLI_TOOL_NAME}"
[[ -x "$CLI" ]] || CLI="${SCRIPT_ROOT_DIR}/${CLI_TOOL_NAME}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--cli-dir)
            CLI="${2%/}/${CLI_TOOL_NAME}"
            shift 2
            ;;
        -n|--night-mode)
            if [[ "$2" == "0" || "$2" == "false" || "$2" == "off" ]]; then
                NIGHT_MODE_ON=false
            fi
            shift 2
            ;;
        -w|--write-protocol)
            WRITE_PROTOCOL="-write-protocol $2"
            shift 2
            ;;
    esac
done



# LEDs OFF during this window, ON the rest of the day. Minutes since midnight.
# Default = off 11:00 PM (1380) to 7:00 AM (420).
OFF_START_MIN=$((23*60 + 0))   # 11:00 PM
OFF_END_MIN=$((7*60 +  0))     # 7:00 AM

# Solid color levels when on.
BRIGHT_IDLE=200
BRIGHT_NET=200
BRIGHT_POWER=200

# Colors (R G B).
COLOR_POWER="255 255 255"   # power LED = white
COLOR_NET_UP="0 255 0"     # LAN up = blue
COLOR_NET_DOWN="255 165 0"    # LAN link down = orange
COLOR_HEALTHY_DISK="0 255 0"    # healthy disk = green
COLOR_FAILED_DISK="255 0 0"    # failed disk = red

# How long the LED is held dark during an activity blink (seconds).
BLINK_DARK=0.15

# Minimum sectors of disk I/O (since last poll) to count as "real" activity.
# Filters trivial ZFS background chatter. 512-byte sectors; 2048 ~= 1 MiB.
# Raise if idle disks still blink; lower for more sensitivity.
ACTIVITY_THRESHOLD=2048

# Minimum bytes of network traffic (rx+tx, since last poll) to blink the LAN
# LED. Filters idle background chatter. 1048576 = 1 MiB per poll.
NET_THRESHOLD=1048576

# How often to poll counters (seconds).
IO_POLL=0.5 # every 0.5 seconds

# Slow refresh cadence (pool health, SMART, link state, schedule), in cycles.
HEALTH_EVERY=60 # every 30 seconds, 60 * IO_POLL (60 x 0.5 s = 30 seconds)

ZPOOL=/usr/sbin/zpool
[[ -x "$ZPOOL" ]] || ZPOOL=/sbin/zpool

### ──────────────────────────── SETUP ────────────────────────────

modprobe i2c-dev 2>/dev/null || true

if [[ ! -x "$CLI" ]]; then
    echo "ERROR: CLI not found/executable at $CLI" >&2
    exit 1
fi

declare -A DISK_LED
declare -A DISK_STATFILE
declare -A LAST_IO

build_disk_map() {
    DISK_LED=()
    DISK_STATFILE=()
    while read -r name hctl; do
        [[ -z "$name" || -z "$hctl" ]] && continue
        host="${hctl%%:*}"
        [[ "$host" =~ ^[0-9]+$ ]] || continue
        led="disk$((host + 1))"
        DISK_LED["$name"]="$led"
        DISK_STATFILE["$name"]="/sys/block/${name}/stat"
        LAST_IO["$name"]=0
    done < <(lsblk -S -o NAME,HCTL | tail -n +2)
}

io_counter() {
    local f="$1"
    [[ -r "$f" ]] || { echo 0; return; }
    awk '{print $3 + $7}' "$f" 2>/dev/null || echo 0
}

# ---- network helpers ----
# List physical NICs: has a device symlink, not wireless, not virtual.
PHYS_NICS=()
build_nic_list() {
    PHYS_NICS=()
    local dev
    for dev in /sys/class/net/*; do
        [[ -e "$dev/device" ]] || continue     # skip lo, docker0, bridges, vlans
        [[ -d "$dev/wireless" ]] && continue    # skip wifi
        PHYS_NICS+=( "$(basename "$dev")" )
    done
}

# Total rx+tx bytes summed across all physical NICs.
net_counter() {
    local total=0 n rx tx
    for n in "${PHYS_NICS[@]}"; do
        rx=$(cat "/sys/class/net/$n/statistics/rx_bytes" 2>/dev/null || echo 0)
        tx=$(cat "/sys/class/net/$n/statistics/tx_bytes" 2>/dev/null || echo 0)
        total=$(( total + rx + tx ))
    done
    echo "$total"
}

# Is any physical NIC carrier-up?
net_link_up() {
    local n carrier
    for n in "${PHYS_NICS[@]}"; do
        carrier=$(cat "/sys/class/net/$n/carrier" 2>/dev/null || echo 0)
        [[ "$carrier" == "1" ]] && return 0
    done
    return 1
}

disk_health() {
    local dev="$1"
    local smart
    smart=$(/usr/sbin/smartctl -H "/dev/$dev" 2>/dev/null \
            | grep -i "overall-health" | awk '{print $NF}')
    if [[ -n "$smart" && "${smart^^}" != "PASSED" && "${smart^^}" != "OK" ]]; then
        echo "fault"; return
    fi
    local state
    state=$($ZPOOL status -L 2>/dev/null \
            | awk -v d="$dev" '$1 ~ "^"d"[0-9]*$" {print $2; exit}')
    case "$state" in
        ONLINE|"") echo "ok" ;;
        DEGRADED)  echo "degraded" ;;
        *)         echo "fault" ;;
    esac
}

any_pool_unhealthy() {
    $ZPOOL status -x 2>/dev/null | grep -qv "all pools are healthy"
}

leds_should_be_on() {
    if [[ "$NIGHT_MODE_ON" == "false" ]]; then
        return 0
    fi
    local now h m
    h=$(date +%-H); m=$(date +%-M)
    now=$((h*60 + m))
    if (( OFF_START_MIN <= OFF_END_MIN )); then
        (( now < OFF_START_MIN || now >= OFF_END_MIN ))
    else
        (( now < OFF_START_MIN && now >= OFF_END_MIN ))
    fi
}

all_off() {
    "$CLI" all $WRITE_PROTOCOL -off >/dev/null 2>&1
}

set_led() {
    local name="$1" color="$2" bright="$3"; shift 3
    "$CLI" "$name" $WRITE_PROTOCOL -color $color -on -brightness "$bright" "$@" >/dev/null 2>&1
}

### ─────────────────────── HEALTH STATE CACHE ───────────────────────
declare -A DISK_BASECOLOR
declare -A DISK_BLINK
POWER_COLOR="$COLOR_POWER"
NET_LINK=1
LAST_NET=0

refresh_health() {
    build_disk_map
    build_nic_list
    for dev in "${!DISK_LED[@]}"; do
        case "$(disk_health "$dev")" in
            ok)       DISK_BASECOLOR[$dev]="$COLOR_HEALTHY_DISK"; DISK_BLINK[$dev]=0 ;;
            degraded) DISK_BASECOLOR[$dev]="$COLOR_FAILED_DISK"; DISK_BLINK[$dev]=1 ;;
            fault)    DISK_BASECOLOR[$dev]="$COLOR_FAILED_DISK"; DISK_BLINK[$dev]=0 ;;
        esac
    done
    if any_pool_unhealthy; then POWER_COLOR="255 0 0"; else POWER_COLOR="$COLOR_POWER"; fi
    if net_link_up; then NET_LINK=1; else NET_LINK=0; fi
}

paint_netdev() {
    if (( NET_LINK )); then
        set_led netdev "$COLOR_NET_UP" "$BRIGHT_NET"
    else
        set_led netdev "$COLOR_NET_DOWN" "$BRIGHT_NET"
    fi
}

### ──────────────────────────── MAIN LOOP ────────────────────────────

cleanup() { all_off; exit 0; }
trap cleanup INT TERM

OFF_ACTIVE=0
refresh_health
LAST_NET=$(net_counter)
cycle=0

paint_static() {
    set_led power "$POWER_COLOR" "$BRIGHT_POWER"
    paint_netdev
    for dev in "${!DISK_LED[@]}"; do
        local led="${DISK_LED[$dev]}"
        if (( ${DISK_BLINK[$dev]:-0} )); then
            "$CLI" "$led" $WRITE_PROTOCOL -color ${DISK_BASECOLOR[$dev]} -blink 400 600 -brightness "$BRIGHT_IDLE" >/dev/null 2>&1
        else
            set_led "$led" "${DISK_BASECOLOR[$dev]}" "$BRIGHT_IDLE"
        fi
        LAST_IO[$dev]=$(io_counter "${DISK_STATFILE[$dev]}")
    done
    LAST_NET=$(net_counter)
}

if leds_should_be_on; then paint_static; else all_off; OFF_ACTIVE=1; fi

while true; do
    if ! leds_should_be_on; then
        if (( OFF_ACTIVE == 0 )); then all_off; OFF_ACTIVE=1; fi
        sleep 30
        continue
    else
        if (( OFF_ACTIVE == 1 )); then OFF_ACTIVE=0; refresh_health; paint_static; fi
    fi

    if (( cycle % HEALTH_EVERY == 0 )); then
        cycle=0 # to prevent overflow
        refresh_health
        set_led power "$POWER_COLOR" "$BRIGHT_POWER"
    fi

    # ---- LAN activity blink ----
    if (( NET_LINK )); then
        net_now=$(net_counter)
        net_delta=$(( net_now - LAST_NET ))
        (( net_delta < 0 )) && net_delta=$(( -net_delta ))
        if (( net_delta >= NET_THRESHOLD )); then
            "$CLI" netdev $WRITE_PROTOCOL -off >/dev/null 2>&1
            sleep "$BLINK_DARK"
            set_led netdev "$COLOR_NET_UP" "$BRIGHT_NET"
        else
            set_led netdev "$COLOR_NET_UP" "$BRIGHT_NET"
        fi
        LAST_NET=$net_now
    else
        set_led netdev "$COLOR_NET_DOWN" "$BRIGHT_NET"
    fi

    # ---- per-disk activity blink (healthy disks only) ----
    for dev in "${!DISK_LED[@]}"; do
        led="${DISK_LED[$dev]}"
        base="${DISK_BASECOLOR[$dev]:-$COLOR_HEALTHY_DISK}"
        if [[ "$base" != "$COLOR_FAILED_DISK" ]]; then continue; fi

        now=$(io_counter "${DISK_STATFILE[$dev]}")
        prev=${LAST_IO[$dev]:-0}
        delta=$(( now - prev ))
        (( delta < 0 )) && delta=$(( -delta ))
        if (( delta >= ACTIVITY_THRESHOLD )); then
            "$CLI" "$led" $WRITE_PROTOCOL -off >/dev/null 2>&1
            sleep "$BLINK_DARK"
            set_led "$led" "$COLOR_HEALTHY_DISK" "$BRIGHT_IDLE"
        else
            set_led "$led" "$COLOR_HEALTHY_DISK" "$BRIGHT_IDLE"
        fi
        LAST_IO[$dev]=$now
    done

    cycle=$((cycle + 1))
    sleep "$IO_POLL"
done
#!/bin/bash
#
# !!! THIS SCRIPT WASN'T TESTED. USE AT YOUR OWN RISK. !!!
#
# How to use:
# set-app-icon proxy https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/nginx-proxy-manager.svg
# or if you want to use an icon from a local file:
# set-app-icon my-app file:///root/my_icon.svg

set -o errexit
set -o pipefail

main() {
	local app="$1"; shift
	local icon_uri="$1"; shift

	local apps_dir; apps_dir="$(get_apps_dir)"
	local meta_dir="$apps_dir"/app_configs/"$app"/
	[ -f "$meta_dir"/metadata.yaml ] || die "can't find metadata for application '$app'"

	local icon_data; icon_data="$(curl -f "$icon_uri" | base64 -w0)"

	cd "$meta_dir"	
	yq -i '.metadata.icon="data:image/svg+xml;base64,'"$icon_data"'"' metadata.yaml
}

yq() {
	docker run --rm -u$UID --security-opt=no-new-privileges --cap-drop all --network none \
		-v "${PWD}":/workdir mikefarah/yq "$@"
}

get_apps_dir() {
	local dataset; dataset="$(midclt call docker.config | jq -r '.dataset')"
	zfs get mountpoint "$dataset" -o value -H
}

die() {
	local code=1
	if [ $# -gt 1 ]; then code="$1"; shift; fi
	printf '%s\n' "$*" 1>&2
	exit "$code"
}

main "$@"
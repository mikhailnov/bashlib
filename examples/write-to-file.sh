#!/bin/bash

# Example request:
# http://localhost/cgi-bin/r8168.cgi?rev=0x00&probe=b0cdd5070e

# https://github.com/mikhailnov/bashlib, https://abf.io/import/bashlib
. bashlib ||{ echo "Failed to source bashlib!" ; exit 1 ;}

readonly file="/var/www/r8168.list"
readonly lock="/var/www/r8168.lock"
readonly rev="$(safe_param rev)"
readonly probe="$(safe_param probe)"

# possible values: 0x15, 0x09
if ! [[ "$rev" =~ ^0x..$ ]]; then
	echo "Status: 400 Bad request"
	echo "Content-Type: text/plain; charset=utf-8"
	echo ""
	echo "Incorrect value of rev"
	exit 1
fi

if [ ${#probe} -gt 20 ] || ! [[ "$probe" =~ ^[a-zA-Z0-9]+$ ]]; then
	echo "Status: 400 Bad request"
	echo "Content-Type: text/plain; charset=utf-8"
	echo ""
	echo "Incorrect value of probe"
	exit 1
fi

set -e
echo "$rev;$probe" | flock "$lock" tee -a "$file" >/dev/null
echo "Status: 200 OK"
echo "Content-Type: text/plain; charset=utf-8"
echo ""
echo "OK"

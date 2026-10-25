#!/bin/bash
set -euo pipefail
umask 022
cd "$(dirname "$0")"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/DEBIAN" "$stage/usr/libexec/roothidepatcherfix" debs
install -m 644 src/control src/triggers "$stage/DEBIAN/"
install -m 755 src/postinst src/prerm "$stage/DEBIAN/"
install -m 755 src/manage.sh "$stage/usr/libexec/roothidepatcherfix/"
install -m 644 src/rpath_dedup.awk src/functions.sh src/insert.awk src/manifest "$stage/usr/libexec/roothidepatcherfix/"
for script in src/manage.sh src/postinst src/prerm src/functions.sh; do bash -n "$script"; done
dpkg-deb --root-owner-group -Zxz -b "$stage" debs/com.gokuencinar.roothidepatcherfix_1.0.1_iphoneos-arm64e.deb

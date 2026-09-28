#!/usr/bin/env bash
set -euo pipefail

: > Packages
for package_dir in tweaks/*/debs; do
  [ -d "$package_dir" ] || continue
  dpkg-scanpackages -m "$package_dir" /dev/null >> Packages
done
gzip -9 -c Packages > Packages.gz

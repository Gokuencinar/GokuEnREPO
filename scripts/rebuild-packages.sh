#!/usr/bin/env bash
set -euo pipefail

: > Packages
# Only publish packages from each tweak's dedicated debs/ directory.
for package_dir in tweaks/*/debs; do
  [ -d "$package_dir" ] || continue
  dpkg-scanpackages -m "$package_dir" /dev/null >> Packages
done
gzip -9 -c Packages > Packages.gz

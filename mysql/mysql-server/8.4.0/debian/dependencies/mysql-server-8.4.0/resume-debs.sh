#!/bin/bash
set -euo pipefail
workspace=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$workspace/src/mysql-8.4.0"
export CC=/usr/bin/gcc-14 CXX=/usr/bin/g++-14
export MYSQL_BUILD_MAKE_JFLAG=-j32
export DEB_BUILD_OPTIONS='parallel=32 nocheck noautodbgsym'
cmake --build release --parallel 32
rm -f override_dh_auto_install override_dh_installinit
dpkg-buildpackage -b -nc -uc -us -j32

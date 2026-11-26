#!/bin/bash
set -euo pipefail
workspace=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$workspace/src/mysql-8.4.0"
export CC=/usr/bin/gcc-14
export CXX=/usr/bin/g++-14
export MYSQL_BUILD_MAKE_JFLAG=-j32
export DEB_BUILD_OPTIONS='parallel=32 nocheck noautodbgsym'
dpkg-buildpackage -b -uc -us -j32

#! /bin/bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -ex

export_or_prefix() {
    export OPENRESTY_PREFIX="/usr/local/openresty-debug"
    export PATH=$OPENRESTY_PREFIX/nginx/sbin:$OPENRESTY_PREFIX/luajit/bin:$OPENRESTY_PREFIX/bin:$PATH
    openresty -V
}

install_lua_deps() {
    export_or_prefix
    echo "install lua deps"

    make deps
    luarocks install luacov-coveralls --tree=deps --local > build.log 2>&1 || (cat build.log && exit 1)

}

before_install() {
    sudo cpanm --notest Test::Nginx >build.log 2>&1 || (cat build.log && exit 1)
    sleep 5
}

do_install() {
    wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
    sudo apt-get -y update --fix-missing
    sudo apt-get -y install software-properties-common
    sudo add-apt-repository -y "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main"
    sudo add-apt-repository -y ppa:longsleep/golang-backports

    sudo apt-get update
    sudo apt-get install openresty-debug

    lua_version=lua-5.3.5
    if [ ! -f "build-cache/${lua_version}" ]; then
        cd build-cache
        curl -R -O http://www.lua.org/ftp/${lua_version}.tar.gz
        tar -zxf ${lua_version}.tar.gz
        cd ..
    fi
    cd ${lua_version}
    make linux test
    sudo make install
    cd ..

    luarocks_version=luarocks-3.3.1
    if [ ! -f "build-cache/${luarocks_version}" ]; then
        cd build-cache
        wget https://luarocks.org/releases/${luarocks_version}.tar.gz
        tar zxpf ${luarocks_version}.tar.gz
        cd ..
    fi
    cd ${luarocks_version}
    ./configure --prefix=/usr > build.log 2>&1 || (cat build.log && exit 1)
    make build > build.log 2>&1 || (cat build.log && exit 1)
    sudo make install > build.log 2>&1 || (cat build.log && exit 1)
    cd ..

    sudo luarocks install luacheck > build.log 2>&1 || (cat build.log && exit 1)

    install_lua_deps

    # sudo apt-get install tree -y
    # tree deps

}

script() {
    export_or_prefix
    sudo service etcd start

    make license-check
    make init
    make test
    make start-background
    sleep 2
    make benchmark-wrk
    make stop
    sleep 1
    cat logs/error.log
}

after_success() {
    # cat luacov.stats.out
    # luacov-coveralls
    cat benchmark/out/wrk.out
}

case_opt=$1
shift

case ${case_opt} in
before_install)
    before_install "$@"
    ;;
do_install)
    do_install "$@"
    ;;
script)
    script "$@"
    ;;
after_success)
    after_success "$@"
    ;;
esac

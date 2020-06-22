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
    export GO111MOUDULE=on
    echo $GOPATH
    echo $GOROOT
}

install_etcd() {
    export ETCDCTL_API=3
    ETCD_VER=v3.4.9
    BUILD_DIR=build-cache/etcd
    BIN_DIR=${BUILD_DIR}/bin

    if [ ! -f "${BIN_DIR}/etcd" ]; then
        mkdir -p ${BIN_DIR}
        # choose either URL
        # GOOGLE_URL=https://storage.googleapis.com/etcd
        GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
        DOWNLOAD_URL=${GITHUB_URL}

        curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o ${BUILD_DIR}/etcd-${ETCD_VER}-linux-amd64.tar.gz
        tar xzvf $BUILD_DIR/etcd-${ETCD_VER}-linux-amd64.tar.gz -C ${BIN_DIR} --strip-components=1
        rm -f $BUILD_DIR/etcd-${ETCD_VER}-linux-amd64.tar.gz
    fi
    
    ${BIN_DIR}/etcd --version
    ${BIN_DIR}/etcdctl version
    # start etcd server
    nohup ${BIN_DIR}/etcd > etcd.log 2>&1 &
    sleep 3

    ${BIN_DIR}/etcdctl --endpoints=localhost:2379 put foo bar
    ${BIN_DIR}/etcdctl --endpoints=localhost:2379 get foo
}


install_lua_deps() {
    export_or_prefix
    echo "install lua deps"

    make deps
    luarocks install luacov-coveralls --tree=deps --local > build.log 2>&1 || (cat build.log && exit 1)

}

before_install() {
    sudo cpanm --notest Test::Nginx >build.log 2>&1 || (cat build.log && exit 1)
    sleep 1
}

do_install() {
    wget -qO - https://openresty.org/package/pubkey.gpg | sudo apt-key add -
    sudo apt-get -y update --fix-missing
    sudo apt-get -y install software-properties-common
    sudo add-apt-repository -y "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main"
    sudo add-apt-repository -y ppa:longsleep/golang-backports
    sudo apt-get update
    sudo apt-get install openresty-debug golang-go

    lua_version=lua-5.3.5
    if [ ! -f "build-cache/${lua_version}" ]; then
        cd build-cache
        curl -R -O http://www.lua.org/ftp/${lua_version}.tar.gz
        tar -zxf ${lua_version}.tar.gz
        cd ..
    fi
    cd build-cache/${lua_version}
    make linux test
    sudo make install
    cd ../../

    luarocks_version=luarocks-3.3.1
    if [ ! -f "build-cache/${luarocks_version}" ]; then
        cd build-cache
        wget https://luarocks.org/releases/${luarocks_version}.tar.gz
        tar zxpf ${luarocks_version}.tar.gz
        cd ..
    fi
    cd build-cache/${luarocks_version}
    ./configure --prefix=/usr > build.log 2>&1 || (cat build.log && exit 1)
    make build > build.log 2>&1 || (cat build.log && exit 1)
    sudo make install > build.log 2>&1 || (cat build.log && exit 1)
    cd ../../

    sudo luarocks install luacheck > build.log 2>&1 || (cat build.log && exit 1)

    install_etcd
    install_lua_deps

}

script() {
    export_or_prefix

    make license-check
    make init
    make test
    make start-background
    sleep 2
    make benchmark-wrk
    make stop
    sleep 1
    tail -n50 logs/error.log
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

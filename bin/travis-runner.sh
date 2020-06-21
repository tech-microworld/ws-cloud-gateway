#!/usr/bin/env bash


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

    curl -R -O http://www.lua.org/ftp/lua-5.3.5.tar.gz
    tar -zxf lua-5.3.5.tar.gz
    cd lua-5.3.5
    make linux test
    sudo make install
    cd ..
    rm -rf lua-5.3.5

    wget https://luarocks.org/releases/luarocks-3.3.1.tar.gz
    tar zxpf luarocks-3.3.1.tar.gz
    cd luarocks-3.3.1
    ./configure --prefix=/usr > build.log 2>&1 || (cat build.log && exit 1)
    make build > build.log 2>&1 || (cat build.log && exit 1)
    sudo make install > build.log 2>&1 || (cat build.log && exit 1)
    cd ..
    rm -rf luarocks-3.3.1

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
    make benchmark-wrk

    sleep 1
    cat logs/error.log

}

after_success() {
    cat luacov.stats.out
    luacov-coveralls
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

package = "ws-cloud-gateway"
version = "master-0"
supported_platforms = {"linux", "macosx"}

source = {
    url = "git@github.com:tech-microworld/ws-cloud-gateway.git",
    branch = "master",
}

description = {
    summary = "基于 openresty + etcd 实现的轻量级网关服务",
    homepage = "http://tech-microworld.github.io/ws-cloud/gateway/",
    license = "Apache License 2.0",
}

dependencies = {
    "lua-resty-ngxvar = 0.5",
    "lua-resty-etcd = 0.9",
    "lua-resty-balancer = 0.02rc5",
    "lua-resty-jit-uuid = 0.0.7",
    "lua-resty-jwt = 0.2.2",
    "lua-resty-cookie = 0.1.0",
    "lua-resty-session = 2.24",
    "lua-resty-prometheus = 1.0",
    "lua-resty-radixtree = 1.8",
    "lua-resty-healthcheck = 2.0.0"
}

build = {
    type = "make",
    build_variables = {
        CFLAGS="$(CFLAGS)",
        LIBFLAG="$(LIBFLAG)",
        LUA_LIBDIR="$(LUA_LIBDIR)",
        LUA_BINDIR="$(LUA_BINDIR)",
        LUA_INCDIR="$(LUA_INCDIR)",
        LUA="$(LUA)",
        OPENSSL_INCDIR="$(OPENSSL_INCDIR)",
        OPENSSL_LIBDIR="$(OPENSSL_LIBDIR)",
    },
    install_variables = {
        ENV_INST_PREFIX="$(PREFIX)",
        ENV_INST_BINDIR="$(BINDIR)",
        ENV_INST_LIBDIR="$(LIBDIR)",
        ENV_INST_LUADIR="$(LUADIR)",
        ENV_INST_CONFDIR="$(CONFDIR)",
    },
}

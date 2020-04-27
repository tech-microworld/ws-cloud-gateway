package = "resty-gateway"
version = "dev-0"
supported_platforms = {"linux", "macosx"}

source = {
    url = "git@github.com:fengjx/resty-gateway.git",
    branch = "v1.0",
}

description = {
    summary = "基于openresty + etcd实现的网关服务",
    homepage = "https://blog.fengjx.com/openresty/gateway/",
    license = "Apache License 2.0",
}

dependencies = {
    "lua-resty-ngxvar = 0.5",
    "lua-resty-etcd = 0.9",
    "lua-resty-balancer = 0.02rc5",
    "lua-resty-jit-uuid = 0.0.7",
    "lua-resty-jwt = 0.2.0",
    "lua-resty-cookie = 0.1.0",
    "lua-resty-session = 2.24",
    "lua-resty-prometheus = 1.0"
}

build = {
    type = "make",
    build_variables = {
    },
    install_variables = {
    },
}

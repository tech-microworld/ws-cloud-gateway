local cjson = require "cjson"
local const = require("my.const")

local _M = {}

local app_config = {}
local app_env = nil

local config = {
    test = {
        appName = "resty-gateway",
        discovery = {
            etcd = {
                http_host = "http://192.168.1.102:2379",
                etcdctl_api = "3",
                api_prefix = "/v3",
                service_register_path = "/micros/service"
            },
            open_api_prefix = "/open/api",
            inner_api_prefix = "/inner/api"
        }
    },
    prod = {}
}

_M.init = function (env)
    app_env = env
    ngx.log(ngx.ERR, "config init env: " .. env);
    app_config = config[env]
    ngx.log(ngx.ERR, "appName: " .. app_config[const.APP_NAME]);
end

_M.get = function (key)
    return app_config[key]
end

-- 是否是测试环境
_M.is_test = function ()
    return app_env == "test"
end

return _M
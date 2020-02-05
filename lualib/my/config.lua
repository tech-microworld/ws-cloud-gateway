local cjson = require "cjson"
local const = require("my.const")

local _M = {}

local app_config = {}

_M.load = function (config_file)
    ngx.log(ngx.ERR, "load config file: " .. config_file);
    local confFile = io.open(config_file, "r");
    local confStr = confFile:read("*a");
    ngx.log(ngx.ERR, "load cnfig: " .. confStr);
    confFile:close();
    app_config = cjson.decode(confStr);
    ngx.log(ngx.ERR, "appName: " .. app_config[const.APP_NAME]);
end

_M.get = function (key)
    return app_config[key]
end

return _M
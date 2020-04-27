--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local cjson = require "cjson"
local log = require("app.core.log")
local str_utils = require("app.utils.str_utils")
local ngx_config = ngx.config
local error = error

local _M = {}

local app_config = {}

function _M.init(config_file)
    if not str_utils.start_with(config_file, "/") then
        config_file = ngx_config.prefix() .. config_file
    end
    log.info("load config file: " .. config_file)
    local confFile = io.open(config_file, "r")
    local confStr = confFile:read("*a")
    log.info("load cnfig: " .. confStr)
    confFile:close()
    app_config = cjson.decode(confStr)
end

local function get(key)
    if not app_config then
        error("etcd config not init")
        return nil
    end
    return app_config[key]
end

_M.get = get

-- 获取etcd配置
function _M.get_etcd_config()
    return get("etcd")
end

-- 是否是测试环境
function _M.is_test()
    return not app_config.env == "prod"
end

return _M

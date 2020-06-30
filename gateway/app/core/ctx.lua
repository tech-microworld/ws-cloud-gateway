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
local require = require
local log = require("app.core.log")
local dispatcher = require("app.core.dispatcher")
local call_utils = require("app.utils.call_utils")
local pcall = pcall
local pairs = pairs
local ngx = ngx
local config = require("app.config")
local tab_nkeys = require("table.nkeys")
local router = require("app.core.router")

local _M = {}

local plugins = {}

local function install_plugins()
    local plugin_list = config.get("plugins")
    for _, file_name in pairs(plugin_list) do
        local ok, plugin = pcall(require, "app.plugins." .. file_name)
        if not ok then
            log.error("failed to install plugin [", file_name, "]: ", plugin)
        else
            plugins[plugin.name] = plugin
            local func = plugin["do_in_init"]
            if func then
                func()
            end
            log.info("install plugin:", plugin.name)
        end
    end
end

function _M.init()
    log.info("ctx init")
    install_plugins()
end

function _M.init_worker()
    log.info("ctx init worker")
    call_utils.call(plugins, "do_in_init_worker")
end

-- 从上下文中获取dispatcher
function _M.get_dispatcher()
    local ngx_ctx = ngx.ctx
    local ctx_dispatcher = ngx_ctx.dispatcher
    if not ctx_dispatcher then
        local route = router.match(ngx.var.uri)
        if not route then
            route = {
                prefix = ngx.var.uri,
                status = 1,
                service_name = "default",
                protocol = "http",
                plugins = {
                    "default"
                }
            }
        end

        if not route or tab_nkeys(route.plugins) == 0 then
            route.plugins = {"default"}
        end

        local dispatcher_plugins = {}
        for _, plugin_name in pairs(route.plugins) do
            dispatcher_plugins[plugin_name] = plugins[plugin_name]
        end
        ctx_dispatcher = dispatcher:new(dispatcher_plugins, route)
        ngx_ctx.dispatcher = ctx_dispatcher
    end
    return ctx_dispatcher
end

function _M.plugins()
    return plugins
end

return _M

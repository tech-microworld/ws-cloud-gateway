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
local get_var = require("resty.ngxvar").fetch
local ngx = ngx
local get_method = ngx.req.get_method
local ngx_exit = ngx.exit
local ipairs = ipairs
local pairs = pairs
local log = require("app.core.log")
local core_table = require("app.core.table")
local radixtree = require("resty.radixtree")

local _M = {}

local router
local req_mapping = {}

local function check_token(ctx)
    log.info("check token")
    return true
end

local function handler_fun(fun)
    return function()
        -- 从 body 中读取数据
        ngx.req.read_body()
        check_token()
        fun()
    end
end

local function mapping(apis)
    for _, a in ipairs(apis) do
        core_table.insert(
            req_mapping,
            {
                paths = a.paths,
                methods = a.methods,
                handler = handler_fun(a.handler)
            }
        )
    end
end

function _M.init_worker()
    local resources = {
        login = require("admin.login"),
        routes = require("admin.routes"),
        services = require("admin.services")
    }

    for _, res in pairs(resources) do
        mapping(res.apis)
    end
    router = radixtree.new(req_mapping)
    log.info("admin init")
end

function _M.http_admin()
    local ok = router:dispatch(get_var("uri"), {method = get_method()})
    if not ok then
        ngx_exit(404, "not dound")
    end
end

return _M

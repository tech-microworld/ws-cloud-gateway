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
local pairs = pairs
local ipairs = ipairs
local log = require("app.core.log")
local core_table = require("app.core.table")
local lrucache = require("app.core.lrucache")
local radixtree = require("resty.radixtree")
local str_utils = require("app.utils.str_utils")

local _M = {}

local router_cache
local radix_cache

do
    router_cache = lrucache:new("router.routes", {count = 100, ttl = nil})
    radix_cache = lrucache:new("router.radix", {count = 3, ttl = 60 * 10})
end -- end do

local function get_all_routes()
    local keys = router_cache:get_keys(0)
    local routes = {}
    for _, v in ipairs(keys) do
        core_table.insert(routes, router_cache:get(v))
    end
    return routes
end

local function create_rx()
    local routes = get_all_routes()
    local mapping = {}
    for path, route in pairs(routes) do
        core_table.insert(
            mapping,
            {
                paths = {path},
                metadata = route
            }
        )
    end
    return radixtree:new(mapping)
end

-- 匹配路由
function _M.match(url)
    log.info("match route url: ", url)
    local rx = radix_cache:fetch_cache("rx", true, create_rx)
    local route = rx:match(url)
    log.info("match route: ", str_utils.table_to_string(route))
    return route
end

local function create_route(route)
    log.info("create route: ", str_utils.table_to_string(route))
    return route
end

-- 注册路由
function _M.register(path, route)
    router_cache:set_by_create(path, create_route, route)
end

-- 删除路由
function _M.delete(path)
    router_cache:delete(path)
end

return _M

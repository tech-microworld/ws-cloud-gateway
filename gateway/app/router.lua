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
local ipairs = ipairs
local log = require("app.core.log")
local core_table = require("app.core.table")
local lrucache = require("app.core.lrucache")
local radixtree = require("resty.radixtree")
local json = require("app.core.json")
local route_store = require("app.store.route_store")
local tab_nkeys = require("table.nkeys")

local _M = {}

local radix_cache = lrucache.new({ttl = 60, count = 1})
local rx_key = "router.rx"

local function create_rx()
    local routes, err = route_store.query_enable_routers()
    if not routes or tab_nkeys(routes) < 1 then
        log.notice("routers is empty")
        return nil, err
    end
    log.info("routes: ", json.delay_encode(routes))

    local mapping = {}
    for _, route in ipairs(routes) do
        core_table.insert(
            mapping,
            {
                paths = {route.prefix},
                hosts = route.hosts,
                metadata = route
            }
        )
    end
    log.info("mapping: ", json.delay_encode(mapping))
    return radixtree.new(mapping)
end

-- 匹配路由
function _M.match(url, match_opts)
    local rx = radix_cache:fetch_cache(rx_key, false, create_rx)
    if not rx then
        return nil
    end
    local route = rx:match(url, match_opts)
    log.info("match route: ", json.delay_encode({url, route}))
    return route
end

-- 注册路由
function _M.refresh()
    radix_cache:set(rx_key, create_rx())
end

return _M

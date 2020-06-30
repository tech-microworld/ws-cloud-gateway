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
local ngx = ngx
local timer_at = ngx.timer.at
local ipairs = ipairs
local pairs = pairs
local etcd = require("app.core.etcd")
local log = require("app.core.log")
local tab_nkeys = require("table.nkeys")
local str_utils = require("app.utils.str_utils")
local core_table = require("app.core.table")
local time = require("app.core.time")
local router = require("app.core.router")

local _M = {}

local etcd_prefix = "routes"

-- 构造路由前缀
local function get_etcd_key(key)
    return str_utils.join_str("", etcd_prefix, key)
end

-- 路由配置是否存在
local function is_exsit(key)
    local key = get_etcd_key(key)
    local res, err = etcd.get(key)
    return not err and res.body.kvs and tab_nkeys(res.body.kvs) > 0
end

_M.is_exsit = is_exsit

-- 查询所有路由配置，返回 list
local function query_list()
    local resp, err = etcd.readdir(etcd_prefix)
    if err ~= nil then
        log.error("failed to load routes", err)
        return nil, err
    end

    local routes = {}
    if resp.body.kvs and tab_nkeys(resp.body.kvs) > 0 then
        for _, kv in ipairs(resp.body.kvs) do
            core_table.insert(routes, kv.value)
        end
    end
    return routes, nil
end

_M.query_list = query_list

local function query_routes()
    local list, err = query_list()
    if not list and tab_nkeys(list) < 1  then
        return nil, err
    end

    local routes = {}
    for _, route in ipairs(list) do
        routes[route.prefix] = route
    end
    return routes, nil
end

-- 删除路由
local function remove_route(key)
    log.alert("remove route: ", key)
    local etcd_key = get_etcd_key(key)
    local _, err = etcd.delete(etcd_key)
    if not err then
        router.delete(key)
    end
    return err
end

_M.remove_route = remove_route

-- 保存路由配置
function _M.save_route(route)
    route.key = route.prefix
    local key = str_utils.trim(route.key)
    local etcd_key = get_etcd_key(key)
    route.time = time.now() * 1000
    local _, err = etcd.set(etcd_key, route)
    if err then
        log.error("save route error: ", err)
        return err
    end
    if route.status == 1 then
        router.register(route.prefix, route)
    else
        router.delete(key)
    end
    return nil
end

local function load_routes()
    local routes, err = query_routes()
    if err then
        log.error("load routes fail: ", err)
        return
    end
    for _, route in pairs(routes) do
        if route.status ~= 1 then
            goto CONTINUE
        end

        router.register(route.prefix, route)

        ::CONTINUE::
    end
end

-- 初始化
function _M.init()
    if 0 ~= ngx.worker.id() then
        log.info("worker id is not 0 and do nothing")
        return
    end
    local ok, err = timer_at(0, load_routes)
    if not ok then
        log.error("failed to load routes: ", err)
    end
end

return _M

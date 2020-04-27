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
local cjson = require("cjson")
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
local routes_cache = ngx.shared.routes_cache

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

-- 注册和更新路由配置
local function apply_route(route)
    local route_info = cjson.encode(route)
    routes_cache:safe_set(route.key, route_info)
    log.alert("apply route: ", route.key, " => ", route_info)
end

-- 通过uri查询路由配置
local function get_route_by_uri(uri)
    if str_utils.is_blank(uri) then
        return nil
    end
    local route_info, _ = routes_cache:get(uri)
    log.info("get route from cache ==> uri:", uri, ", route_info: ", route_info)
    if route_info then
        local route = cjson.decode(route_info)
        if not route.props then
            route.props = {}
        end
        return route
    end
    -- 递归父级uri
    local parent_uri = str_utils.substr_before_last(uri, "/")
    return get_route_by_uri(parent_uri)
end

_M.get_route_by_uri = get_route_by_uri

local function query_routes()
    local resp, err = etcd.readdir(etcd_prefix)
    if err ~= nil then
        log.error("failed to load routes", err)
        return
    end

    local routes = {}
    if resp.body.kvs and tab_nkeys(resp.body.kvs) > 0 then
        for _, node in ipairs(resp.body.kvs) do
            local route = node.value
            routes[route.prefix] = route
        end
        return routes, nil
    end
    return nil, "route is empty"
end

_M.query_routes = query_routes

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

-- 删除缓存配置
local function delete_route_cache(route_prefix)
    routes_cache:delete(route_prefix)
end

-- 删除路由
local function remove_route(key)
    log.alert("remove route: ", key)
    local etcd_key = get_etcd_key(key)
    local _, err = etcd.delete(etcd_key)
    if not err then
        delete_route_cache(key)
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
        return err
    end
    if route.status == 1 then
        apply_route(route)
    else
        delete_route_cache(key)
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
        apply_route(route)
    end
end

-- 初始化
function _M.init()
    local ok, err = timer_at(0, load_routes)
    if not ok then
        log.error("failed to load routes: ", err)
    end
end

return _M

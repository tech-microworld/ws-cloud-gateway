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
local error = error
local ipairs = ipairs
local etcd = require("app.core.etcd")
local log = require("app.core.log")
local tab_nkeys = require("table.nkeys")
local str_utils = require("app.utils.str_utils")
local core_table = require("app.core.table")
local time = require("app.core.time")
local router = require("app.core.router")
local timer = require("app.core.timer")
local json = require("app.core.json")

local _M = {}

local route_timer
local route_watch_timer
-- 防止网络异常导致路由数据监听处理失败，未及时更新路由信息，定时轮训路由配置
local route_refresh_timer

local etcd_prefix = "routes"

local etcd_watch_opts = {
    timeout = 60,
    prev_kv = true
}

-- 构造路由前缀
local function get_etcd_key(key)
    return str_utils.join_str("", etcd_prefix, key)
end

-- 路由配置是否存在
local function is_exsit(key)
    local etcd_key = get_etcd_key(key)
    local res, err = etcd.get(etcd_key)
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

local function query_enable_list()
    local list, err = query_list()
    if not list and tab_nkeys(list) < 1 then
        return nil, err
    end

    local routes = {}
    for _, route in ipairs(list) do
        if route.status == 1 then
            core_table.insert(routes, route)
        end
    end
    return routes, nil
end

_M.query_enable_list = query_enable_list

local function refresh_router()
    local routes, err = query_enable_list()
    if not routes and tab_nkeys(routes) < 1 then
        return nil, err
    end
    router.refresh(routes)
end

local function watch_routes(ctx)
    log.info("watch routes start_revision: ", ctx.start_revision)
    local opts = {
        timeout = etcd_watch_opts.timeout,
        prev_kv = etcd_watch_opts.prev_kv,
        start_revision = ctx.start_revision
    }
    local chunk_fun, err = etcd.watchdir(etcd_prefix, opts)

    if not chunk_fun then
        log.error("routes chunk err: ", err)
        return
    end
    while true do
        local chunk
        chunk, err = chunk_fun()
        if not chunk then
            if err ~= "timeout" then
                log.error("routes chunk err: ", err)
            end
            break
        end
        log.info("routes watch result: ", json.delay_encode(chunk.result))
        ctx.start_revision = chunk.result.header.revision + 1
        if chunk.result.events then
            for _, event in ipairs(chunk.result.events) do
                log.error("routes event: ", event.type, " - ", json.delay_encode(event.kv))
                refresh_router()
            end
        end
    end
end

-- 删除路由
local function remove_route(key)
    log.error("remove route: ", key)
    local etcd_key = get_etcd_key(key)
    local _, err = etcd.delete(etcd_key)
    if not err then
        refresh_router()
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
    refresh_router()
    return nil
end

local function _init()
    refresh_router()
    route_watch_timer:recursion()
    route_refresh_timer:every()
end

-- 初始化
function _M.init()
    route_timer = timer.new("route.timer", _init, {delay = 0})
    route_refresh_timer = timer.new("route.refresh.timer", refresh_router, {delay = 3})
    route_watch_timer = timer.new("route.watch.timer", watch_routes, {delay = 0})
    local ok, err = route_timer:once()
    if not ok then
        error("failed to load routes: " .. err)
    end
end

return _M

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
local require = require
local etcd = require("app.core.etcd")
local log = require("app.core.log")
local tab_nkeys = require("table.nkeys")
local str = require("app.utils.str_utils")
local core_table = require("app.core.table")
local time = require("app.core.time")
local timer = require("app.core.timer")
local json = require("app.core.json")

local router

local _M = {}

local route_timer
local route_watch_timer

local etcd_prefix = "routes/"

local etcd_watch_opts = {
    timeout = 60,
    prev_kv = true
}

local function create_key(prefix)
    return str.md5(str.trim(prefix))
end

_M.create_key = create_key

-- 构造路由前缀
local function get_etcd_key(key)
    return str.join_str("", etcd_prefix, key)
end

-- 路由配置是否存在
local function is_exsit(prefix)
    local etcd_key = get_etcd_key(create_key(prefix))
    local res, err = etcd.get(etcd_key)
    return not err and res.body.kvs and tab_nkeys(res.body.kvs) > 0
end

_M.is_exsit = is_exsit

-- 查询所有路由配置，返回 list
local function query_list()
    local resp, err = etcd.readdir(etcd_prefix)
    if err ~= nil then
        log.error("failed to load routes: ", err)
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

local function query_enable_routers()
    local list, err = query_list()
    if not list or tab_nkeys(list) < 1 then
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

_M.query_enable_routers = query_enable_routers

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
                log.error("routes event: ", event.type, " - ", json.delay_encode(event))
                router.refresh()
            end
        end
    end
end

-- 删除路由
local function remove_route(key)
    log.notice("remove route: ", key)
    local etcd_key = get_etcd_key(key)
    local _, err = etcd.delete(etcd_key)
    if err then
        log.error("remove route error: ", err)
        return false, err
    end
    return true, nil
end

_M.remove_route = remove_route

-- 根据 url 前缀删除路由配置
local function remove_route_by_prefix(prefix)
    log.notice("remove route by prefix: ", prefix)
    local key = create_key(prefix)
    return remove_route(key)
end

_M.remove_route_by_prefix = remove_route_by_prefix

-- 保存路由配置
local function save_route(route)
    local key = create_key(route.prefix)
    route.key = key
    local etcd_key = get_etcd_key(key)
    route.time = time.now() * 1000
    local _, err = etcd.set(etcd_key, route)
    if err then
        log.error("save route error: ", err)
        return false, err
    end
    return true, nil
end

_M.save_route = save_route

function _M.update_route(route)
    local key = route.key
    -- 检查路由是否已经存在
    if str.is_blank(key) and is_exsit(route.prefix) then
        return false, "路由[" .. route.prefix .. "]配置已存在"
    end

    local _, err = save_route(route)
    -- 如果路由前缀修改了，需要删除之前的路由配置
    if err == nil and key and key ~= route.prefix then
        _, err = remove_route(key)
    end
    if err then
        log.error("update route error: ", err)
        return false, err
    end
    return true, nil
end

local function _init()
    router.refresh()
    route_watch_timer:recursion()
end

-- 初始化
function _M.init()
    router = require("app.router")
    route_timer = timer.new("route.timer", _init, {delay = 0})
    route_watch_timer = timer.new("route.watch.timer", watch_routes, {delay = 0})
    local ok, err = route_timer:once()
    if not ok then
        error("failed to load routes: " .. err)
    end
end

return _M

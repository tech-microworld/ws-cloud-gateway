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
local error = error
local ipairs = ipairs
local pairs = pairs
local type = type
local tab_nkeys = require("table.nkeys")
local log = require("app.core.log")
local time = require("app.core.time")
local etcd = require("app.core.etcd")
local core_table = require("app.core.table")
local timer = require("app.core.timer")
local json = require("app.core.json")
local str = require("app.utils.str_utils")
local lrucache = require("app.core.lrucache")
local balancer

local _M = {}

local discovery_timer
local discovery_watcher_timer

local service_nodes_cache = lrucache.new({ttl = 300, count = 512})

local delete_type = "DELETE"
local etcd_prefix = "discovery/"

local etcd_watch_opts = {
    timeout = 60,
    prev_kv = true
}

-- 根据服务名和 upstream 获取 etcd key
local function service_node_etcd_key(key)
    if key == nil then
        error("key is nil")
    end
    if type(key) ~= "string" then
        error("key must be a string")
    end
    return etcd_prefix .. key
end

local function create_key(service_name, upstream)
    if service_name == nil or upstream == nil then
        error("service_name or upstream is nil")
    end
    if type(service_name) ~= "string" or type(upstream) ~= "string" then
        error("service_name or upstream  must be a string")
    end
    return str.join_str(".", service_name, str.md5(str.trim(service_name) .. str.trim(upstream)))
end

local function create_service_prefix(service_name)
    return service_node_etcd_key(service_name)
end

local function create_service_upstream_prefix(service_name, upstream)
    return service_node_etcd_key(create_key(service_name, upstream))
end

local function parse_node(service)
    return {
        key = create_key(service.service_name, service.upstream),
        service_name = service.service_name,
        upstream = service.upstream,
        weight = service.weight,
        status = service.status,
        time = service.time or time.now() * 1000
    }
end

-- 服务节点是否存在
local function is_exsit(service)
    local prefix = create_service_upstream_prefix(service.service_name, service.upstream)
    local res, err = etcd.get(prefix)
    return not err and res.body.kvs and tab_nkeys(res.body.kvs) > 0
end

_M.is_exsit = is_exsit

-- 如果 service_name 为空，则查询所有服务的所有节点
local function find_node_list(servive_name)
    local prefix = servive_name and create_service_prefix(servive_name) or etcd_prefix
    log.notice("find_node_list prefix: ", prefix)
    local resp, err = etcd.readdir(prefix)
    if err then
        log.info("failed to query service list, key: ", prefix, ", err: ", err)
        return nil, err
    end

    local nodes = {}
    etcd_watch_opts.start_revision = resp.body.header.revision + 1
    if resp.body.kvs and tab_nkeys(resp.body.kvs) > 0 then
        for _, kv in ipairs(resp.body.kvs) do
            core_table.insert(nodes, parse_node(kv.value))
        end
    end
    return nodes, nil
end

_M.find_node_list = find_node_list

-- 根据服务名查询在线服务节点
local function find_node_list_by_cache(service_name, is_active)
    local node_list = service_nodes_cache:fetch_cache(
        service_name, false, find_node_list, service_name)
    if not is_active or not node_list then
        return node_list
    end
    log.notice("find_node_list_by_cache: ", service_name, " - ", json.delay_encode(node_list))
    local res = {}
    for _, node in ipairs(node_list) do
        if node.status ~= 1 then
            goto CONTINUE
        end
        core_table.insert(res, node)

        ::CONTINUE::
    end
    return res
end

_M.find_node_list_by_cache = find_node_list_by_cache

-- 从 etcd 读取所有服务节点，按 service_name 分组
local function find_group_node_list(is_active)
    local list = find_node_list()
    if not list or tab_nkeys(list) < 1 then
        return nil
    end

    local group = {}
    for _, node in ipairs(list) do
        if is_active and node.status ~= 1 then
            goto CONTINUE
        end

        local nodes = group[node.service_name] or {}
        core_table.insert(nodes, node)
        group[node.service_name] = nodes

        ::CONTINUE::
    end
    return group
end

-- 删除节点信息
local function remove_node(node)
    local service_name = node.service_name
    service_nodes_cache:delete(service_name)
    local node_list = find_node_list_by_cache(service_name, true)
    balancer.delete(node.service_name, node.upstream, node_list)
end

-- 更新服务节点信息
local function apply_balancer(node)
    -- 下线状态，删除缓存服务节点
    if node.status == 0 then
        remove_node(node)
        return
    end

    local service_name = node.service_name
    local upstream = node.upstream
    local weight = node.weight
    -- etcd 数据变更，设置缓存数据
    service_nodes_cache:delete(service_name)
    local node_list = find_node_list_by_cache(service_name, true)
    balancer.set(service_name, upstream, weight, node_list)
end

-- 从 etcd 删除服务节点
local function delete_etcd_node(key)
    local _, err = etcd.delete(service_node_etcd_key(key))
    if not err then
        return false, err
    end
    return true, nil
end

_M.delete_etcd_node = delete_etcd_node

-- 设置服务节点到 etcd
local function set_service_node(node)
    local old_key = node.key
    local payload = parse_node(node)
    local _, err
    -- key 不相同，则是更新节点，需要删除旧节点
    if old_key and old_key ~= payload.key then
        _, err = delete_etcd_node(old_key)
    end
    if err then
        log.error("delete service node error: ", err, " - ", payload.key)
        return false, err
    end
    _, err = etcd.set(service_node_etcd_key(payload.key), payload)
    if err then
        log.error("save service node error: ", err, " - ", json.delay_encode(node))
        return false, err
    end
    return true, nil
end

_M.set_service_node = set_service_node

-- 监听服务节点数据变更
local function watch_services(ctx)
    log.info("watch services start_revision: ", ctx.start_revision)
    local opts = {
        timeout = etcd_watch_opts.timeout,
        prev_kv = etcd_watch_opts.prev_kv,
        start_revision = ctx.start_revision
    }
    local chunk_fun, err = etcd.watchdir(etcd_prefix, opts)

    if not chunk_fun then
        log.error("services chunk err: ", err)
        return
    end
    while true do
        local chunk
        chunk, err = chunk_fun()
        if not chunk then
            if err ~= "timeout" then
                log.error("services chunk err: ", err)
            end
            break
        end
        log.info("services watch result: ", json.delay_encode(chunk.result))
        ctx.start_revision = chunk.result.header.revision + 1
        if chunk.result.events then
            for _, event in ipairs(chunk.result.events) do
                log.info("services event: ", event.type, " - ", json.delay_encode(event))
                if delete_type == event.type then
                    remove_node(parse_node(event.prev_kv.value))
                else
                    apply_balancer(parse_node(event.kv.value))
                end
            end
        end
    end
end

-- 加载服务节点注册信息
local function load_services()
    local group = find_group_node_list(true)
    if group and tab_nkeys(group) > 0 then
        for name, nodes in pairs(group) do
            service_nodes_cache:set(name, nodes)
            balancer.refresh(name, nodes)
        end
    else
        log.warn("can't find any service and nodes")
    end
end

-- etcd初始化
local function _init()
    load_services()
    discovery_watcher_timer:recursion()
end

function _M.init()
    balancer = require("app.upstream.balancer")
    discovery_timer = timer.new("discovery.timer", _init, {delay = 0})
    discovery_watcher_timer = timer.new("discovery.watcher.timer", watch_services, {delay = 0})
    local ok, err = discovery_timer:once()
    if not ok then
        error("failed to init discovery: " .. err)
    end
end

return _M

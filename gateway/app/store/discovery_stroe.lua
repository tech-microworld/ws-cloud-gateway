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
local tab_nkeys = require("table.nkeys")
local log = require("app.core.log")
local time = require("app.core.time")
local error = error
local ipairs = ipairs
local pairs = pairs
local etcd = require("app.core.etcd")
local core_table = require("app.core.table")
local balancer = require("app.core.balancer")
local timer = require("app.core.timer")
local json = require("app.core.json")

local discovery_timer
local discovery_watcher_timer
-- 防止网络异常导致节点数据监听处理失败，未及时更新服务节点信息，定时轮训服务节点
local discovery_refresh_timer

local _M = {}

local delete_type = "DELETE"
local etcd_prefix = "discovery"

local etcd_watch_opts = {
    timeout = 60,
    prev_kv = true
}

-- 根据服务名和 upstream 获取 etcd key
local function service_node_etcd_key(key)
    return etcd_prefix .. key
end

local function create_service_key(service_name)
    return "/" .. service_name
end

local function create_key(service_name, upstream)
    return create_service_key(service_name) .. "/" .. upstream
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
    local key = create_key(service.service_name, service.upstream)
    local res, err = etcd.get(service_node_etcd_key(key))
    return not err and res.body.kvs and tab_nkeys(res.body.kvs) > 0
end

_M.is_exsit = is_exsit

local function find_by_prefix(prefix)
    prefix = prefix and service_node_etcd_key(prefix) or etcd_prefix
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

-- 通过服务名查询节点信息
function _M.find_nodes_by_name(service_name)
    return find_by_prefix(create_service_key(service_name))
end

-- 从 etcd 读取所有服务节点列表
local function query_service_node_list()
    return find_by_prefix()
end

_M.query_service_node_list = query_service_node_list

-- 从 etcd 读取所有服务节点 {service_name = node_list}
local function query_services_nodes()
    local list = query_service_node_list()
    if not list and tab_nkeys(list) < 1 then
        return nil
    end

    local nodes = {}
    for _, node in ipairs(list) do
        if node.status ~= 1 then
            goto CONTINUE
        end

        local items = nodes[node.service_name] or {}
        items[node.upstream] = node.weight
        nodes[node.service_name] = items

        ::CONTINUE::
    end
    return nodes
end

_M.query_services_nodes = query_services_nodes

-- 更新服务节点信息
local function apply_balancer(node)
    local service_name = node.service_name
    local service_upstream = node.upstream
    local weight = node.weight

    -- 下线状态，删除缓存服务节点
    if node.status == 0 then
        balancer.delete(service_name, service_upstream)
        return
    end
    balancer.set(service_name, service_upstream, weight)
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
                log.error("routes event: ", event.type, " - ", json.delay_encode(event.kv))
                local node = parse_node(event.kv.value)
                if delete_type == event.type then
                    balancer.delete(node.service_name, node.upstream)
                else
                    apply_balancer(node)
                end
            end
        end
    end
end

-- 加载服务节点注册信息
local function load_services()
    local nodes = query_services_nodes()
    if nodes and tab_nkeys(nodes) > 0 then
        for name, items in pairs(nodes) do
            balancer.refresh(name, items)
        end
    else
        log.info("service nodes empty")
    end
end

-- etcd初始化
local function _init()
    load_services()
    discovery_watcher_timer:recursion()
    discovery_refresh_timer:every()
end

function _M.init()
    discovery_timer = timer.new("discovery.timer", _init, {delay = 0})
    discovery_refresh_timer = timer.new("discovery.refresh.timer", load_services, {delay = 3})
    discovery_watcher_timer = timer.new("discovery.watcher.timer", watch_services, {delay = 0})
    local ok, err = discovery_timer:once()
    if not ok then
        error("failed to init discovery: " .. err)
    end
end

return _M

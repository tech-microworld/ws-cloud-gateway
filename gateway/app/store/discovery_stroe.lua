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
local cjson = require "cjson"
local tab_nkeys = require("table.nkeys")
local log = require("app.core.log")
local time = require("app.core.time")
local ngx = ngx
local timer_at = ngx.timer.at
local ipairs = ipairs
local etcd = require("app.core.etcd")
local core_table = require("app.core.table")
local service_cache = ngx.shared.discovery_cache

local _M = {}

local delete_type = "DELETE"
local etcd_prefix = "discovery"

local etcd_watch_opts = {
    timeout = 60,
    prev_kv = true,
    start_revision = nil
}

-- 根据服务名和 upstream 获取 etcd key
local function service_node_etcd_key(key)
    return etcd_prefix .. key
end

local function get_key(service_name, upstream)
    return "/" .. service_name .. "/" .. upstream
end

local function parse_node(service)
    return {
        key = get_key(service.service_name, service.upstream),
        service_name = service.service_name,
        upstream = service.upstream,
        weight = service.weight,
        status = service.status,
        time = service.time or time.now() * 1000
    }
end

-- 服务节点是否存在
local function is_exsit(service)
    local key = get_key(service.service_name, service.upstream)
    local res, err = etcd.get(service_node_etcd_key(key))
    return not err and res.body.kvs and tab_nkeys(res.body.kvs) > 0
end

_M.is_exsit = is_exsit

-- 从 etcd 读取所有服务节点
local function service_node_list()
    local resp, err = etcd.readdir(etcd_prefix)
    if err then
        log.info("failed to query service list", err)
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

_M.service_node_list = service_node_list

-- 根据服务名查询节点列表
local function get_service_nodes_cache(service_name)
    local nodes = service_cache:get(service_name)
    if not nodes then
        return nil
    end
    log.debug("get service nodes from cache: ", service_name, " - ", nodes)
    return cjson.decode(nodes)
end

_M.get_service_nodes_cache = get_service_nodes_cache

-- 删除缓存中的服务节点
local function remove_node_cache(service_name, upstream)
    local nodes = get_service_nodes_cache(service_name)
    if nodes and tab_nkeys(nodes) > 0 then
        nodes[upstream] = nil
        service_cache:set(service_name, cjson.encode(nodes))
        log.info("remove service node cache: ", service_name, "/", upstream)
    end
end

-- 更新服务节点信息
local function apply_service_node(node)
    local service_name = node.service_name
    local service_upstream = node.upstream

    -- 删除缓存服务节点
    if node.status == 0 then
        remove_node_cache(service_name, service_upstream)
        return
    end
    log.info("cache srevice node: ", cjson.encode(node))
    local weight = node.weight
    local nodes = get_service_nodes_cache(service_name) or {}
    nodes[service_upstream] = weight
    service_cache:set(service_name, cjson.encode(nodes))
end

-- 从 etcd 删除服务节点
local function delete_etcd_node(key)
    local _, err = etcd.delete(service_node_etcd_key(key))
    return err
end

_M.delete_etcd_node = delete_etcd_node

-- 保存服务节点到 etcd
local function save_service_node(service)
    local old_key = service.key
    local payload = parse_node(service)
    local _, err
    -- key 不相同，则是更新节点，需要删除旧节点
    if old_key and old_key ~= payload.key then
        _, err = delete_etcd_node(old_key)
    end
    if err then
        log.error("delete service node error: ", err, " - ", payload.key)
        return err
    end
    _, err = etcd.set(service_node_etcd_key(payload.key), payload)
    if err then
        log.error("save service node error: ", err, " - ", cjson.encode(service))
        return err
    end
    apply_service_node(service)
    return nil
end

_M.save_service_node = save_service_node


-- 监听服务节点数据变更
local function watch_services()
    if 0 ~= ngx.worker.id() then
        log.debug("worker id is not 0 and do nothing")
        return
    end

    log.info("watch start_revision: " .. etcd_watch_opts.start_revision)
    local chunk_fun, err = etcd.watchdir(etcd_prefix, etcd_watch_opts)

    if not chunk_fun then
        log.error("failed to watch: ", err)
        return
    end
    while true do
        local chunk
        chunk, err = chunk_fun()
        if not chunk then
            log.error("chunk err: ", err)
            local ok
            ok, err = timer_at(0, watch_services)
            if not ok then
                log.error("failed to watch services: ", err)
            end
            break
        end
        log.info("watch result: ", cjson.encode(chunk.result))
        etcd_watch_opts.start_revision = chunk.result.header.revision + 1
        if chunk.result.events then
            for _, event in ipairs(chunk.result.events) do
                local node = parse_node(event.kv.value)
                if delete_type == event.type then
                    remove_node_cache(node.service_name, node.upstream)
                else
                    apply_service_node(node)
                end
            end
        end
    end
end

-- 加载服务节点注册信息
local function load_services()
    if 0 ~= ngx.worker.id() then
        log.info("worker id is not 0 and do nothing")
        return
    end

    local nodes, err = service_node_list()
    if err then
        log.info("failed to load nodes", err)
        return
    end

    if nodes and tab_nkeys(nodes) > 0 then
        for _, node in ipairs(nodes) do
            apply_service_node(node)
        end
    else
        log.info("service nodes empty")
    end
end

-- etcd初始化
local function init_discovery()
    load_services()
    watch_services()
end

function _M.init()
    local ok, err = timer_at(0, init_discovery)
    if not ok then
        log.error("failed to init discovery: ", err)
    end
end

return _M

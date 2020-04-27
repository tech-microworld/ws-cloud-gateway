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
local ngx = ngx
local timer_at = ngx.timer.at
local ipairs = ipairs
local str_utils = require("app.utils.str_utils")
local etcd = require("app.core.etcd")
local service_cache = ngx.shared.discovery_cache

local _M = {}

local delete_type = "DELETE"
local etcd_prefix = "discovery/"

local etcd_watch_opts = {
    timeout = 60,
    prev_kv = true,
    start_revision = nil
}

-- etcd key 前缀
local function full_etcd_prefix()
    return str_utils.join_str("", etcd.get_prefix(), etcd_prefix)
end

-- 查询所有服务节点信息
local get_all_service_nodes = function()
    local service_nodes = {}
    for _, name in ipairs(service_cache:get_keys()) do
        service_nodes[name] = service_cache:get(name)
    end
    return service_nodes
end

_M.get_all_service_nodes = get_all_service_nodes

-- 根据服务名查询节点列表
local function get_service_nodes(service_name)
    local nodes = service_cache:get(service_name)
    if not nodes then
        return nil
    end
    return cjson.decode(nodes)
end

_M.get_service_nodes = get_service_nodes

-- 更新服务节点信息
local function put_service_node(node_data, is_remove)
    if is_remove == nil then
        is_remove = false
    end
    local node = str_utils.str_sub(node_data.key, #full_etcd_prefix() + 1)
    local arr = str_utils.split(node, "/")
    local service_name = arr[1]
    local service_upstream = arr[2]
    local weight = node_data.value
    local nodes = get_service_nodes(service_name) or {}
    if is_remove then
        nodes[service_upstream] = nil
        log.alert("remove service node: ", node)
    else
        nodes[service_upstream] = weight
        log.alert("discovery service node: ", node)
    end
    service_cache:set(service_name, cjson.encode(nodes))
end

local function watch_services()
    if 0 == ngx.worker.id() then
        log.debug("worker id is not 0 and do nothing")
        return
    end

    log.info("watch start_revision: " .. etcd_watch_opts.start_revision)
    local chunk_fun, err = etcd.watchdir(full_etcd_prefix(), etcd_watch_opts)

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
        etcd_watch_opts.start_revision = chunk.result.header.revision + 1
        if chunk.result.events then
            for _, event in ipairs(chunk.result.events) do
                put_service_node(event.kv, delete_type == event.type)
                get_all_service_nodes()
            end
        end
    end
end

-- 加载服务节点注册信息
local function load_services()
    if 0 == ngx.worker.id() then
        log.debug("worker id is not 0 and do nothing")
        return
    end
    local resp, err = etcd.readdir(etcd_prefix)
    if err then
        log.info("failed to load services", err)
        return
    end

    etcd_watch_opts.start_revision = resp.body.header.revision + 1
    if resp.body.kvs and tab_nkeys(resp.body.kvs) > 0 then
        for _, kv in ipairs(resp.body.kvs) do
            put_service_node(kv)
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

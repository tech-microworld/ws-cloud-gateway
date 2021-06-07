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
local ngx_balancer = require("ngx.balancer")
local lrucache = require("app.core.lrucache")
local resty_roundrobin = require("resty.roundrobin")
local resty_chash = require("resty.chash")
local log = require("app.core.log")
local json = require("app.core.json")
local tab_nkeys = require("table.nkeys")
local ipairs = ipairs
local str = require("app.utils.str_utils")
local healthcheck = require("app.upstream.healthcheck")
local get_last_failure = ngx_balancer.get_last_failure

local _M = {}

local upstream_type_cache = ngx.shared.upstream_type_cache
local balancer_cache = lrucache.new({ttl = 60, count = 256})
local lrucache_addr = lrucache.new({ttl = 60, count = 256})

local function parse_addr(addr)
    local host, port, err = str.parse_addr(addr)
    return {host = host, port = port}, err
end

local function parse_server(upstream)
    return lrucache_addr:fetch_cache(upstream, false, parse_addr, upstream)
end

function _M.set_upstream_type(service_name, type)
    upstream_type_cache:set(service_name, type)
end

-- TODO: 后面设计成动态配置
local function get_upstream_type(service_name)
    return upstream_type_cache:get(service_name) or "roundrobin"
end

_M.get_upstream_type = get_upstream_type

-- doc: https://github.com/openresty/lua-resty-balancer
local balancer_types = {
    chash = function(nodes)
        return resty_chash:new(nodes)
    end,
    roundrobin = function(nodes)
        return resty_roundrobin:new(nodes)
    end
}

-- 添加监控检查 upstream
local function add_healthcheck(service_name, upstream, node_list)
    log.notice("add_healthcheck: ", service_name, ", ", upstream)
    local up_server = parse_server(upstream)
    healthcheck.add_target(service_name, up_server.host, up_server.port, node_list)
end

local function new_balancer(service_name, nodes)
    local type = get_upstream_type(service_name)
    log.info("new balancer: ", json.delay_encode({service_name, type, nodes}))
    local balancer_up = balancer_types[type](nodes)
    return balancer_up
end

local function create_balancer(service_name, node_list)
    local nodes_up = {}
    for _, node in ipairs(node_list) do
        nodes_up[node.upstream] = node.weight
    end

    if not nodes_up or tab_nkeys(nodes_up) < 1 then
        log.info("server nodes is empty for ", service_name)
        return
    end
    log.notice("create balancer: ", service_name, " - ", json.delay_encode(nodes_up))
    return new_balancer(service_name, nodes_up)
end

-- 通过服务名获取 balancer 缓存
local function get_balancer_up(service_name, nodes)
    return balancer_cache:fetch_cache(service_name, false, create_balancer, service_name, nodes)
end

-- 刷新服务节点缓存
local function refresh(service_name, nodes)
    balancer_cache:set(service_name, create_balancer(service_name, nodes))
end

_M.refresh = refresh

-- 更新服务节点
function _M.set(service_name, upstream, weight, node_list)
    weight = weight or 1
    local balancer_up = get_balancer_up(service_name, node_list)
    log.notice("set balancer node: ", service_name, ", ", upstream, ", ", weight)
    balancer_up:set(upstream, weight or 1)
    -- 监控检查
    add_healthcheck(service_name, upstream, node_list)
end

-- 查询服务节点
function _M.pick_server(service_name, node_list, api_ctx)
    local nodes_count = node_list and #node_list or 0
    log.alert("service nodes: ", service_name, ", ", json.delay_encode(node_list), ", ", nodes_count)
    if nodes_count == 0 then
        return nil, "no valid upstream node"
    end
    if nodes_count == 1 then
        local node = node_list[1]
        log.notice("only one upstrean server found: ", json.delay_encode(node))
        return parse_server(node.upstream)
    end

    -- 上次请求失败，重试的时候把上个节点状态更新一下
    if api_ctx and api_ctx.balancer_try_count > 1 then
        local state, code = get_last_failure()
        local host = api_ctx.last_balancer_host
        local port = api_ctx.last_balancer_port
        log.error("report server status: ", service_name, ", ", host, ", ", port, ", ", state, ", ", code)
        healthcheck.report(service_name, host, port, state, code)
    end

    local balancer_up = get_balancer_up(service_name, node_list)
    if not balancer_up then
        log.error("can not found service balancer: ", service_name)
        return nil, "can not found service balancer"
    end

    local upstream_addr
    local err
    local ok = false
    local upstream, index = balancer_up:find()
    local first_upstream = upstream
    while not ok do
        upstream_addr, err = lrucache_addr:fetch_cache(upstream, false, parse_addr, upstream)
        if err then
            return nil, err
        end
        -- 当前节点是否正常
        ok = healthcheck.get_target_status(service_name, upstream_addr.host, upstream_addr.port, node_list)
        if ok then
            return parse_server(upstream)
        end
        if index == nil then
            upstream = balancer_up:find()
        else
            upstream = balancer_up:next(index)
            index = index + 1
        end
        log.alert("upstream check: ", first_upstream, ", ", upstream, ", ", index)
        -- 下一个节点和第一个节点相同，说明已经遍历完，已经没有健康节点
        if first_upstream == upstream then
            log.warn("all upstream nodes is unhealth, use default")
            -- 节点监控检查存在延迟，所以在没有健康节点情况下，还是返回 first_upstream
            -- 有可能节点已经恢复。还是尝试请求
            return parse_server(first_upstream)
        end
    end

    return parse_server(first_upstream)
end

-- 删除服务节点
function _M.delete(service_name, upstream, node_list)
    local balancer_up = get_balancer_up(service_name, node_list)
    if balancer_up ~= nil then
        log.notice("remove balancer node: ", service_name, " - ", upstream)
        balancer_up:delete(upstream)
        local up_server = parse_server(upstream)
        healthcheck.remove_target(service_name, up_server.host, up_server.port, node_list)
    end
end

return _M

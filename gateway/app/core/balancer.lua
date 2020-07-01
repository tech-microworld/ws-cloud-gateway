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
local lrucache = require("app.core.lrucache")
local resty_roundrobin = require("resty.roundrobin")
local resty_chash = require("resty.chash")
local log = require("app.core.log")
local json = require("app.core.json")
local ngx = ngx
local upstream_type_cache = ngx.shared.upstream_type_cache

local _M = {}

local balancer_cache

do
    balancer_cache = lrucache:new("balancer", {count = 1024, ttl = nil})
end -- end do

function _M.set_upstream_type(service_name, type)
    upstream_type_cache:set(service_name, type)
end

local function get_upstream_type(service_name)
    return upstream_type_cache:get(service_name) or "roundrobin"
end

_M.get_upstream_type = get_upstream_type

local balancer_types = {
    chash = function(nodes)
        return resty_chash:new(nodes)
    end,
    roundrobin = function(nodes)
        return resty_roundrobin:new(nodes)
    end
}

local _create = function(type, nodes)
    local balancer_up = balancer_types[type](nodes)
    return balancer_up
end

-- 创建 balancer 对象并缓存
local function refresh(service_name, nodes)
    local type = get_upstream_type(service_name)
    log.info("refresh balancer: ", json.delay_encode({service_name, type, nodes}))
    return balancer_cache:set_by_create(service_name, _create, type, nodes)
end

_M.refresh = refresh

-- 通过服务名获取 balancer 缓存
local function get(service_name)
    return balancer_cache:get(service_name)
end

-- 增加服务节点
function _M.set(service_name, upstream, weight)
    log.info("set balancer: ", service_name, " ", upstream, " ", weight)
    weight = weight or 1
    local balancer_up = get(service_name)
    if not balancer_up then
        local nodes = {
            {
                upstream = upstream,
                weight = weight
            }
        }
        refresh(service_name, nodes)
        return
    end
    balancer_up:set(upstream, weight or 1)
end

-- 查询服务节点
function _M.find(service_name)
    local balancer_up = get(service_name)
    if not balancer_up then
        log.info("can not found service balancer: ", service_name)
        return nil
    end
    return balancer_up:find()
end

-- 删除服务节点
function _M.delete(service_name, upstream)
    local balancer_up = get(service_name)
    if balancer_up then
        log.info("delete service balancer: ", service_name, " - ", upstream)
        balancer_up:delete(upstream)
    end
end

return _M

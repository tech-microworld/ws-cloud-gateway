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
local tostring = tostring
local ipairs = ipairs
local lrucache = require("app.core.lrucache")
local log = require("app.core.log")
local json = require("app.core.json")
local config = require("app.config")
local str = require("gateway.app.utils.str_utils")
local discovery_stroe = require("app.store.discovery_stroe")
local healthcheck

local _M = {}

local shm_name = "healthcheck_shm"
local lrucache_checker = lrucache.new({ttl = 60 * 60, count = 512})

local function create_checker(service_name, node_list)
    if healthcheck == nil then
        healthcheck = require("resty.healthcheck")
    end
    node_list = node_list or discovery_stroe.query_nodes(service_name)

    if not node_list or #node_list < 1 then
        local err = "node is empty for service: " .. service_name
        log.warn(err)
        return nil, err
    end

    local checks = config.get("healthcheck")
    local checker =
        healthcheck.new(
        {
            name = "healthcheck#" .. service_name,
            shm_name = shm_name,
            checks = checks
        }
    )
    for _, node in ipairs(node_list) do
        local upstream_arr = str.split(node.upstream, ":")
        log.alert("create and add_target: ", json.delay_encode({service_name, upstream_arr[1], upstream_arr[2]}))
        local ok, err = checker:add_target(upstream_arr[1], upstream_arr[2], service_name, true)
        if not ok then
            log.error("failed to add health check target: ", upstream_arr[1], ":", upstream_arr[2], " err: ", err)
        end
    end
    log.notice("create checker: ", service_name, " - ", tostring(checker))
    return checker
end

local function fetch_healthchecker(service_name, node_list)
    return lrucache_checker:fetch_cache(service_name, false, create_checker, service_name, node_list)
end

-- 添加 upstream 到健康检查
local function add_target(service_name, host, port, nodes_list)
    log.alert("healthchecker add_target: ", json.delay_encode({service_name, host, port}))
    local checker = fetch_healthchecker(service_name, nodes_list)
    local ok, err = checker:add_target(host, port, service_name, true)
    if not ok then
        log.error("failed to add health check target: ", host, ":", port, " err: ", err)
    end
end

_M.add_target = add_target

-- 删除服务节点健康检查
local function uncheck(service_name)
    local checker = lrucache_checker:get(service_name)
    if checker ~= nil then
        checker:stop()
        lrucache_checker:delete(service_name)
    end
end

_M.uncheck = uncheck

-- 删除节点
local function remove_target(service_name, host, port, nodes_list)
    -- 如果节点为空，则移除整个服务节点的监控检查
    if not nodes_list or #nodes_list < 1 then
        uncheck(service_name)
        return
    end

    log.alert("healthchecker add_target: ", json.delay_encode({service_name, host, port}))
    local checker = fetch_healthchecker(service_name, nodes_list)
    local ok, err = checker:remove_target(host, port, service_name)
    if not ok then
        log.error("failed to add health check target: ", host, ":", port, " err: ", err)
    end
end

_M.remove_target = remove_target

-- 检查 upstream 健康状态
function _M.get_target_status(service_name, host, port, node_list)
    local checker = fetch_healthchecker(service_name, node_list)
    local ok, err = checker:get_target_status(host, port, service_name)
    -- 如果是首次 add_target，timer 还没执行会返回 nil，这里先认为是成功
    if ok == nil then
        log.warn("check upstream status warn: ", service_name, ", ", host, ", ", port, " - ", err)
        return true
    end
    return ok
end

-- 设置节点健康状态
function _M.report(service_name, host, port, state, code)
    local checker = fetch_healthchecker(service_name)
    if checker then
        if state == "failed" then
            if code == 504 then
                checker:report_timeout(host, port, service_name)
            else
                checker:report_tcp_failure(host, port, service_name)
            end
        else
            checker:report_http_status(host, port, service_name, code)
        end
    end
end

return _M

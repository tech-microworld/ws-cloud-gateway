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
local ngx = ngx
local log = require("app.core.log")
local json = require("app.core.json")
local route_store = require("app.store.route_store")
local resp = require("app.core.response")
local ngx_balancer = require("ngx.balancer")
local balancer = require("app.upstream.balancer")
local config_get = require("app.config").get
local set_more_tries = ngx_balancer.set_more_tries
local discovery_stroe

local _M = {
    name = "discovery",
    desc = "服务发现插件",
    optional = true,
    version = "v1.0"
}

function _M.do_in_init_worker()
    discovery_stroe = require("app.store.discovery_stroe")
    discovery_stroe.init()
    route_store.init()
end

function _M.do_in_rewrite(route)
    local var = ngx.var
    local ngx_ctx = ngx.ctx
    local api_ctx = ngx_ctx.api_ctx
    local service_name = route.service_name
    -- 放到var，accesslog中可以输出
    var.target_service_name = service_name

    local node_list = discovery_stroe.find_node_list_by_cache(service_name, true)
    if not node_list or #node_list == 0 then
        log.error("server node not found: ", service_name)
        return resp.exit(ngx.HTTP_BAD_GATEWAY)
    end
    api_ctx.node_list = node_list
end

function _M.do_in_balancer(route)
    local api_ctx = ngx.ctx.api_ctx

    api_ctx.balancer_try_count = (api_ctx.balancer_try_count or 0) + 1
    local healthcheck = config_get("healthcheck")
    log.info("healthcheck config: ", json.delay_encode(healthcheck))
    -- 设置重试次数
    if healthcheck and healthcheck.try_count
        and healthcheck.try_count > 0
        and api_ctx.balancer_try_count == 1 then
        log.notice("set_more_tries: ", healthcheck.try_count)
        set_more_tries(healthcheck.try_count)
    end

    local service_name = route.service_name
    local node_list = api_ctx.node_list
    local server, err = balancer.pick_server(service_name, node_list, api_ctx)
    if err then
        log.error("failed to pick server, err: ", err)
        return resp.exit(ngx.HTTP_BAD_GATEWAY)
    end
    api_ctx.balancer_server = server

    local server = api_ctx.balancer_server
    if not server then
        log.error("balancer server is nil")
        return resp.exit(ngx.HTTP_BAD_GATEWAY)
    end

    api_ctx.balancer_host = server.host
    api_ctx.balancer_port = server.port
    log.info("balancer proxy request to ", server.host, ":", server.port)
    ngx_balancer.set_current_peer(server.host, server.port)
end

function _M.do_in_log()
    local ngx_ctx = ngx.ctx
    local api_ctx = ngx_ctx.api_ctx
    api_ctx.last_balancer_host = api_ctx.balancer_host
    api_ctx.last_balancer_port = api_ctx.balancer_port
end

return _M

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
local get_var = require("resty.ngxvar").fetch
local ngx = ngx
local get_method = ngx.req.get_method
local get_headers = ngx.req.get_headers
local ngx_exit = ngx.exit
local ipairs = ipairs
local pairs = pairs
local log = require("app.core.log")
local core_table = require("app.core.table")
local radixtree = require("resty.radixtree")
local resp = require("app.core.response")
local jwt = require "resty.jwt"
local config_get = require("app.config").get

local _M = {}

local router
local req_mapping = {}

local function cors_admin()
    local method = get_method()
    if method == "OPTIONS" then
        resp.set_header(
            "Access-Control-Allow-Origin",
            "*",
            "Access-Control-Allow-Methods",
            "POST, GET, PUT, OPTIONS, DELETE, PATCH",
            "Access-Control-Max-Age",
            "3600",
            "Access-Control-Allow-Headers",
            "*",
            "Access-Control-Allow-Credentials",
            "true",
            "Content-Length",
            "0",
            "Content-Type",
            "text/plain"
        )
        ngx_exit(200)
    end

    resp.set_header(
        "Access-Control-Allow-Origin",
        "*",
        "Access-Control-Allow-Credentials",
        "true",
        "Access-Control-Expose-Headers",
        "*",
        "Access-Control-Max-Age",
        "3600"
    )
end

local function check_api_token()
    local token = get_headers()["X-Api-Token"]
    if not token then
        log.debug("X-Api-Token is empty")
        return false
    end
    local tokens = config_get("tokens")
    if not tokens then
        log.info("no api token settings")
        return false
    end
    if not tokens[token] then
        return false
    end
    log.info("api token auth: ", token)
    return true
end

local function check_token()
    if check_api_token() then
        return
    end

    local token = get_headers()["X-Token"]

    if not token then
        log.error("admin not login")
        resp.exit(ngx.HTTP_UNAUTHORIZED, "用户未登录")
    end

    local jwt_secret = config_get("admin").jwt_secret
    local account = config_get("admin").account

    local session = jwt:verify(jwt_secret, token)

    if not session.valid then
        resp.exit(ngx.HTTP_UNAUTHORIZED, "未登录")
    end

    local username = session.payload.username

    if not username or not account[username] then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "用户不存在")
    end
    local login_user = account[username].info
    login_user.username = username
    ngx.ctx.admin_login_user = login_user
end

local function handler_fun(fun, check_login)
    return function()
        -- 从 body 中读取数据
        ngx.req.read_body()
        if check_login then
            check_token()
        end
        fun()
    end
end

local function mapping(apis)
    for _, a in ipairs(apis) do
        core_table.insert(
            req_mapping,
            {
                paths = a.paths,
                methods = a.methods,
                handler = handler_fun(a.handler, a.check_login == nil and true or a.check_login)
            }
        )
    end
end

function _M.init_worker()
    local resources = {
        login = require("admin.login"),
        routes = require("admin.routes"),
        services = require("admin.services"),
        plugins = require("admin.plugins")
    }

    for _, res in pairs(resources) do
        mapping(res.apis)
    end
    router = radixtree.new(req_mapping)
    log.info("admin init")
end

function _M.http_admin()
    cors_admin()

    local ok = router:dispatch(get_var("uri"), {method = get_method()})
    if not ok then
        ngx_exit(404, "not dound")
    end
end

return _M

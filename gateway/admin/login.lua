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
local cjson = require("cjson")
local jwt = require "resty.jwt"
local ngx = ngx
local now = ngx.now
local update_time = ngx.update_time
local config_get = require("app.config").get
local resp = require("app.core.response")

local function login()
    local jwt_secret = config_get("admin").jwt_secret
    local account = config_get("admin").account
    local body = ngx.req.get_body_data()
    if not body then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "用户名或密码为空")
    end

    local data = cjson.decode(ngx.req.get_body_data())

    if not data or not data.username or not data.password then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "用户名或密码为空")
    end

    local user = account[data.username]
    if not user or user.password ~= data.password then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "用户名或密码错误")
    end

    update_time()
    local token = jwt:sign(jwt_secret,
        {
            header = {typ = "JWT", alg = "HS256"},
            payload = {
                exp = now() + 7 * 24 * 60 + 60,
                username = data.username
            }
        }
    )
    resp.exit(ngx.OK, {token = token})
end

local function info()
    resp.exit(ngx.OK, ngx.ctx.admin_login_user)
end

local function logout()
    resp.exit(ngx.OK, "ok")
end

local _M = {
    apis = {
        {
            paths = {[[/admin/login]]},
            methods = {"POST"},
            handler = login,
            check_login = false
        },
        {
            paths = {[[/admin/user/info]]},
            methods = {"POST", "GET"},
            handler = info
        },
        {
            paths = {[[/admin/logout]]},
            methods = {"POST", "GET"},
            handler = logout
        }
    }
}

return _M

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
local ngx = ngx
local resp = require("app.core.response")
local route_store = require("app.store.route_store")
local str_utils = require("app.utils.str_utils")


local function list()
    local route_list = route_store.query_list()
    resp.exit(ngx.HTTP_OK, route_list)
end

-- 应用路由配置
local function save()
    local body = ngx.req.get_body_data()
    if not body then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "参数不能为空")
    end
    local route = cjson.decode(ngx.req.get_body_data())
    local key = route.key
    -- 检查路由是否已经存在
    if str_utils.is_blank(key) and route_store.is_exsit(route.prefix) then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "路由[" .. route.prefix .. "]配置已存在，请检查!")
        return
    end

    local err = route_store.save_route(route)
    -- 如果路由前缀修改了，需要删除之前的路由配置
    if not err and key and key ~= route.prefix then
        err = route_store.remove_route(key)
    end
    if err then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "路由配置保存失败，请重试")
        return
    end
    resp.exit(ngx.HTTP_OK, "ok")
end

-- 删除路由
local function remove()
    local body = ngx.req.get_body_data()
    if not body then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "参数不能为空")
    end
    local data = cjson.decode(ngx.req.get_body_data())
    local err = route_store.remove_route(data.prefix)
    if err then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "路由配置保存失败，请重试")
    end
    resp.exit(ngx.HTTP_OK, "ok")
end

local _M = {
    apis = {
        {
            paths = {[[/admin/routes/list]]},
            methods = {"GET", "POST"},
            handler = list
        },
        {
            paths = {[[/admin/routes/save]]},
            methods = {"GET", "POST"},
            handler = save
        },
        {
            paths = {[[/admin/routes/remove]]},
            methods = {"POST"},
            handler = remove
        }
    }
}

return _M

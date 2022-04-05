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
local tab_nkeys = require("table.nkeys")
local route_store = require("app.store.route_store")


local function list()
    local route_list = route_store.query_list()
    if not route_list or tab_nkeys(route_list) < 1 then
        resp.exit(ngx.HTTP_OK, "[]")
        return
    end
    resp.exit(ngx.HTTP_OK, route_list)
end

-- 应用路由配置
local function save()
    local body = ngx.req.get_body_data()
    if not body then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "参数不能为空")
    end
    local route = cjson.decode(ngx.req.get_body_data())
    local ok, err = route_store.update_route(route)
    if not ok then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "路由配置保存失败，请重试或联系系统维护人员：" .. err)
        return
    end
    resp.exit(ngx.HTTP_OK, "ok")
end

-- 删除路由
local function remove()
    local body = ngx.req.get_body_data()
    if not body then
        resp.exit(ngx.HTTP_BAD_REQUEST, "参数不能为空")
    end
    local data = cjson.decode(ngx.req.get_body_data())
    local ok, err = route_store.remove_route(data.key)
    if not ok then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "路由删除失败，请重试或联系系统维护人员：" .. err)
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

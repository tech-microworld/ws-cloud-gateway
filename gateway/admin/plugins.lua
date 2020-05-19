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
local ctx = require("app.core.ctx")
local core_table = require("app.core.table")
local resp = require("app.core.response")
local pairs = pairs

local function list()
    local plugins_list = {}
    local plugins = ctx.plugins()
    for _, p in pairs(plugins) do
        if p.optional then
            core_table.insert(plugins_list, {
                name = p.name,
                desc = p.desc .. "_" .. p.version
            })
        end
    end
    resp.exit(ngx.OK, plugins_list)
end

local _M = {
    apis = {
        {
            paths = {[[/admin/plugins/list]]},
            methods = {"GET", "POST"},
            handler = list
        }
    }
}

return _M

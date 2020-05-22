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
local uuid = require "resty.jit-uuid"
local const = require("app.const")
local log = require("app.core.log")
local ngx = ngx

local _M = {
    name = "tracing",
    desc = "链路跟踪插件",
    optional = true,
    version = "v1.0"
}

function _M.do_in_init()
    -- automatic seeding with os.time(), LuaSocket, or ngx.time()
    uuid.seed()
    log.info("jit-uuid init")
end

function _M.do_in_access()
    local req = ngx.req

    local req_id = req.get_headers()[const.HEADER_TRACE_ID]
    if not req_id then
        local trace_id = uuid()
        log.debug("gen trace id: ", trace_id, " ", const.HEADER_TRACE_ID)
        req.set_header(const.HEADER_TRACE_ID, trace_id)
    end
end

return _M

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
local resp = require("app.core.response")
local log = require("app.core.log")

-- optional 是否可选
local _M = {
    name = "default",
    desc = "默认插件",
    optional = false,
    version = "v1.0"
}

function _M.do_in_init()
    -- body
end

function _M.do_in_init_worker()
    -- body
end

function _M.do_in_rewrite()
    log.error("can not match any service")
    resp.exit(ngx.HTTP_NOT_FOUND)
end

function _M.do_in_access()
    -- body
end

function _M.do_in_content()
    -- body
end

function _M.do_in_balancer()
    -- body
end

function _M.do_in_body_filter()
    -- body
end

function _M.do_in_log()
    -- body
end

return _M

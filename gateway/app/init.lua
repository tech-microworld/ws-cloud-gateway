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
local pcall = pcall
local log = require("app.core.log")
local config = require("app.config")
local resp = require("app.core.response")

local _M = {version = 0.1}

function _M.http_init()
    -- 加载配置文件
    local config_file = os.getenv("gateway_config_file") or "conf/app.json"
    config.init(config_file)

    require("app.core.ctx").init()
end

function _M.http_init_worker()
    local ctx = require("app.core.ctx")
    local worker_id = ngx.worker.id()
    log.info("init worker: ", worker_id)

    ctx.init_worker()
end

do

local protocol_handler = {
    http = function(dispatcher)
        dispatcher:do_in_rewrite()
    end,
    grpc = function()
        ngx.exec("@grpc_pass")
    end
}

function _M.http_rewrite()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    local protocol = dispatcher.route.protocol
    local ok = pcall(protocol_handler[protocol], dispatcher)
    if not ok then
        log.error("dispatcher error")
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "dispatcher error")
    end
end

end -- do

function _M.http_access()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    dispatcher:do_in_access()
end

function _M.http_content()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    dispatcher:do_in_content()
end

function _M.http_balancer()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    dispatcher:do_in_balancer()
end

function _M.http_header_filter()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    dispatcher:do_in_header_filter()
end

function _M.http_body_filter()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    dispatcher:do_in_body_filter()
end

function _M.http_log()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    dispatcher:do_in_log()
end

-- grpc
function _M.grpc_rewrite()
    local dispatcher = require("app.core.ctx").get_dispatcher()
    dispatcher:do_in_rewrite()
end

return _M

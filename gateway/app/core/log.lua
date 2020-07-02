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
-- copy from https://github.com/apache/incubator-apisix/blob/master/apisix/core/log.lua

local ngx = ngx
local ngx_log = ngx.log
local require = require
local setmetatable = setmetatable
local tostring = tostring
local str_utils = require("app.utils.str_utils")
local worker_id = ngx.worker.id

local function worker_id_log()
    return str_utils.join_str("", "worker[", tostring(worker_id()), "] - ")
end

local _M = {version = 0.4}

local log_levels = {
    stderr = ngx.STDERR,
    emerg = ngx.EMERG,
    alert = ngx.ALERT,
    crit = ngx.CRIT,
    error = ngx.ERR,
    warn = ngx.WARN,
    notice = ngx.NOTICE,
    info = ngx.INFO,
    debug = ngx.DEBUG
}

local cur_level = ngx.config.subsystem == "http" and require "ngx.errlog".get_sys_filter_level()
local do_nothing = function()
end

function _M.new(prefix)
    local m = {version = _M.version}
    setmetatable(
        m,
        {
            __index = function(self, cmd)
                local log_level = log_levels[cmd]

                local method
                if cur_level and (log_level > cur_level) then
                    method = do_nothing
                else
                    method = function(...)
                        return ngx_log(log_level, prefix, ...)
                    end
                end

                -- cache the lazily generated method in our
                -- module table
                m[cmd] = method
                return method
            end
        }
    )

    return m
end

setmetatable(
    _M,
    {
        __index = function(self, cmd)
            local log_level = log_levels[cmd]

            local method
            if cur_level and (log_level > cur_level) then
                method = do_nothing
            else
                method = function(...)
                    return ngx_log(log_level, worker_id_log(), ...)
                end
            end

            -- cache the lazily generated method in our
            -- module table
            _M[cmd] = method
            return method
        end
    }
)

return _M

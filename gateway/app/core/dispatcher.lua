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
local call_utils = require("app.utils.call_utils")
local log = require("app.core.log")
local setmetatable = setmetatable

local _M = {}

local mt = {__index = _M}

function _M.do_in_rewrite(self)
    call_utils.call(self.plugins, "do_in_rewrite", self.route)
end

function _M.do_in_access(self)
    call_utils.call(self.plugins, "do_in_access", self.route)
end

function _M.do_in_content(self)
    call_utils.call(self.plugins, "do_in_content", self.route)
end

function _M.do_in_balancer(self)
    call_utils.call(self.plugins, "do_in_balancer", self.route)
end

function _M.do_in_header_filter(self)
    call_utils.call(self.plugins, "do_in_body_filter", self.route)
end

function _M.do_in_body_filter(self)
    call_utils.call(self.plugins, "do_in_body_filter", self.route)
end

function _M.do_in_log(self)
    call_utils.call(self.plugins, "do_in_log", self.route)
end

function _M.new(self, plugins, route)
    self.plugins = plugins
    self.route = route
    log.info("new dispatcher ==> ", cjson.encode(route))
    return setmetatable(self, mt)
end

return _M

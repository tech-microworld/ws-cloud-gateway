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
local setmetatable = setmetatable
local error = error
local pcall = pcall
local timer_at = ngx.timer.at
local timer_every = ngx.timer.every
local resty_lock = require("resty.lock")
local log = require("app.core.log")
local time = require("app.core.time")

local _M = {}

local mt = {__index = _M}

function _M.new_lock()
    local lock, err = resty_lock:new("timer_lock")
    if not lock then
        error("failed to create lock: " .. err)
    end
    return lock
end

function _M.new(opts)
    if not opts.name then
        error("missing argument: name")
    end
    local obj = {
        name = opts.name,
        delay = opts.delay or 1,
        callback = opts.callback,
        lock = opts.lock
    }
    return setmetatable(obj, mt)
end

local function callback_fun(callback, name, lock)
    return function(premature)
        if premature then
            log.error("timer[", name, "] is premature")
            return
        end
        if lock then
            local elapsed, err = lock:lock(name)
            if not elapsed then
                log.info("timer[", name, "]failed to acquire the lock: ", err)
                return
            end
        end
        log.info("timer[", name, "] start")
        local start_time = time.now()
        local ok, err = pcall(callback)
        if not ok then
            log.error("failed to run the timer: ", name, " err: ", err)
        end

        if lock then
            lock:unlock()
        end

        local end_time = time.now()
        log.info("timer[", name, "] run finish, take ", end_time - start_time, "ms")
    end
end

function _M.once(self)
    local delay = self.delay
    local name = self.name
    local callback = self.callback
    local lock = self.lock
    return timer_at(delay, callback_fun(callback, name, lock))
end

function _M.every(self)
    local delay = self.delay
    local name = self.name
    local callback = self.callback
    local lock = self.lock
    return timer_every(delay, callback_fun(callback, name, lock))
end

return _M

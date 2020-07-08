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
local type = type
local string = string
local ngx = ngx
local timer_at = ngx.timer.at
local timer_every = ngx.timer.every
local sleep = ngx.sleep
local resty_lock = require("resty.lock")
local log = require("app.core.log")
local time = require("app.core.time")


local _M = {}

local mt = {__index = _M}


local function new_lock()
    local lock, err = resty_lock:new("timer_lock")
    if not lock then
        error("failed to create lock: " .. err)
    end
    return lock
end

function _M.new(name, callback, opts)
    if not name then
        error("missing argument: name")
    end
    if not callback or type(callback) ~= "function" then
        error("missing argument: callback or callback is not a function")
    end
    local lock = nil
    if opts.use_lock then
        lock = new_lock()
    end
    local self = {
        name = name,
        callback = callback,
        delay = opts.delay or 0.5,
        lock = lock,
        fail_sleep_time = opts.fail_sleep_time or 0,
        ctx = {}
    }
    return setmetatable(self, mt)
end

local function callback_fun(self)
    local name = self.name
    local callback = self.callback
    local lock = self.lock
    return function(premature)
        if premature then
            log.error("timer[", name, "] is premature")
            return
        end
        if lock then
            local elapsed, err = lock:lock(name)
            if not elapsed then
                log.info("timer[", name, "] failed to acquire the lock: ", err)
                if self.fail_sleep_time > 0 then
                    sleep(self.fail_sleep_time)
                end
                return
            end
        end
        log.info("timer[", name, "] start")
        local start_time = time.now()
        local ok, err = pcall(callback, self.ctx)
        if not ok then
            log.error("failed to run the timer: ", name, " err: ", err)
        end

        if lock then
            lock:unlock()
        end

        local ms = time.now() - start_time
        log.info("timer[", name, "] run finish, take ", string.format("%.2f", ms), "s")
    end
end

local function recursion_fun(self)
    return function()
        callback_fun(self)()
        timer_at(self.delay, recursion_fun(self))
    end
end

-- 执行一次
function _M.once(self)
    return timer_at(self.delay, callback_fun(self))
end

-- 递归循环执行
function _M.recursion(self)
    return timer_at(self.delay, recursion_fun(self))
end

-- 定时间隔执行
function _M.every(self)
    return timer_every(self.delay, callback_fun(self))
end

return _M

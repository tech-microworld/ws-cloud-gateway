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
local getmetatable = getmetatable
local type = type
local tostring = tostring
local lrucache = require("resty.lrucache")
local log = require("app.core.log")
local resty_lock = require("resty.lock")

local DEFALUT_TTL = -1
local DEFAULT_ITEMS_COUNT = 16
local lua_metatab = {}
local lock_dict_name = "lrucache_lock"

local _M = {}

local mt = {__index = _M}

local function get_val(obj)
    local met_tab = getmetatable(obj)
    if met_tab ~= lua_metatab then
        return obj
    end
    return obj.val
end

local function set_val(obj)
    if type(obj) == "table" then
        return obj
    elseif obj ~= nil then
        return setmetatable({val = obj}, lua_metatab)
    end
end

local function set(self, key, obj)
    local lru = self.lru
    local ttl = self.ttl
    local cached_obj = set_val(obj)
    if ttl < 0 then
        lru:set(key, cached_obj)
    else
        lru:set(key, cached_obj, self.ttl)
    end
end

_M.set = set

local function get(self, key, invalid_stale)
    local lru = self.lru
    local obj, stale_obj = lru:get(key)
    if obj then
        return get_val(obj)
    end
    if not invalid_stale and stale_obj then
        return get_val(stale_obj)
    end
    return nil
end

_M.get = get

-- 从缓存获取数据
-- 如果缓存过期，则获得锁的请求更新数据，没有获得锁的请求先返回过期数据
-- invalid_stale 为 true，则不使用过期缓存，直接返回 nil
function _M.fetch_cache(self, key, invalid_stale, create_val_fun, ...)
    local lru = self.lru
    local obj, stale_obj = lru:get(key)
    if obj then
        return get_val(obj)
    end

    local lock, err = resty_lock:new(lock_dict_name)
    if not lock then
        return nil, "failed to create lock: " .. err
    end

    local key_s = tostring(key)
    local elapsed
    elapsed, err = lock:lock(key_s)

    if not elapsed then
        log.info("failed to acquire the lock: ", err)
        -- 没有获得锁，则从过期缓存返回数据
        if not invalid_stale and stale_obj then
            return get_val(stale_obj)
        end
        return nil
    end

    -- 获得锁成功，则重新获取数据并更新到缓存
    obj = create_val_fun(...)
    set(self, key, obj)
    lock:unlock()
    return obj
end

function _M.delete(self, key)
    self.lru:delete(key)
end

function _M.count(self)
    return self.lru:count()
end

function _M.capacity(self)
    return self.lru:capacity()
end

function _M.get_keys(self, max_count)
    log.info("get keys: ", type(self.lru.get_keys))
    return self.lru:get_keys(max_count)
end

function _M.flush_all(self)
    self.lru:flush_all()
end

function _M.new(opts)
    local lru, err = lrucache.new(opts.count or DEFAULT_ITEMS_COUNT)
    if err then
        return nil, err
    end
    local self = {
        lru = lru,
        ttl = opts.ttl or DEFALUT_TTL
    }
    return setmetatable(self, mt)
end

return _M

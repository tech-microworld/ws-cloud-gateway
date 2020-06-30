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
local lrucache = require("resty.lrucache")
local log = require("app.core.log")

local DEFALUT_TTL = 5
local DEFAULT_ITEMS_COUNT = 10
local lua_metatab = {}

local _M = {}

local mt = {__index = _M}

local function set_by_create(self, key, create_val_fun, ...)
    local lru = self.lru
    local obj = create_val_fun(...)
    local cached_obj
    if type(obj) == "table" then
        cached_obj = obj
    elseif obj ~= nil then
        cached_obj = setmetatable({val = obj}, lua_metatab)
    end
    lru:set(key, cached_obj, self.ttl)
    return obj
end

_M.set_by_create = set_by_create

local function get_val(obj)
    local met_tab = getmetatable(obj)
    if met_tab ~= lua_metatab then
        return obj
    end
    return obj.val
end

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

function _M.fetch_cache(self, key, invalid_stale, create_val_fun, ...)
    local obj = get(self, key, invalid_stale)
    return obj or set_by_create(self, key, create_val_fun, ...)
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

function _M.new(self, opts)
    local lru, err = lrucache.new(opts.count or DEFAULT_ITEMS_COUNT)
    if err then
        return nil, err
    end
    self.lru = lru
    self.ttl = opts.ttl or DEFALUT_TTL
    return setmetatable(self, mt)
end

return _M

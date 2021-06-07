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
local cjson = require "cjson"
local ngx_re = require "ngx.re"
local string = string
local table = table
local tonumber = tonumber
local md5 = ngx.md5
local sub_str = string.sub
local str_byte = string.byte

local _M = {}

local function trim(str)
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

_M.trim = trim

local function split(str, sep)
    return ngx_re.split(str, sep)
end

_M.split = split

local function is_empty(str)
    return not str or str == ""
end

_M.is_empty = is_empty

local function is_blank(str)
    if str == nil then
        return true
    end
    local b = trim(str)
    return b == ""
end

_M.is_blank = is_blank

local str_sub = function(str, start, ending)
    if not ending then
        ending = #str
    end
    return string.char(string.byte(str, start, ending))
end

_M.str_sub = str_sub

local function last_index_of(str, separator)
    local pos = str:reverse():find(separator:reverse(), nil, true)
    if pos then
        return str:len() - separator:len() - pos + 2
    else
        return pos
    end
end

_M.last_index_of = last_index_of

local function substr_before_last(str, separator)
    if is_empty(str) or is_empty(separator) then
        return str
    end
    local pos = last_index_of(str, separator)
    return pos == -1 and str or str_sub(str, 1, pos - 1)
end

_M.substr_before_last = substr_before_last

local function substr_after_last(str, separator)
    if is_empty(str) or is_empty(separator) then
        return str
    end
    local pos = last_index_of(str, separator)
    return pos == -1 and str or str_sub(str, pos + 1, #str)
end

_M.substr_after_last = substr_after_last

_M.start_with = function(str, start)
    return str_sub(str, 1, #start) == start
end

_M.end_with = function(str, ending)
    return ending == "" or str_sub(str, -(#ending)) == ending
end

_M.table_to_string = function(t)
    return cjson.encode(t)
end

_M.join_str = function(joinSpe, ...)
    return table.concat({...}, joinSpe)
end

_M.md5 = function(str)
    return md5(str)
end

local function rfind_char(s, ch, idx)
    local b = str_byte(ch)
    for i = idx or #s, 1, -1 do
        if str_byte(s, i, i) == b then
            return i
        end
    end
    return nil
end

-- parse_addr parses 'addr' into the host and the port parts. If the 'addr'
-- doesn't have a port, 80 is used to return. For malformed 'addr', the entire
-- 'addr' is returned as the host part. For IPv6 literal host, like [::1],
-- the square brackets will be kept.
function _M.parse_addr(addr)
    local default_port = 80
    if str_byte(addr, 1) == str_byte("[") then
        -- IPv6 format
        local right_bracket = str_byte("]")
        local len = #addr
        if str_byte(addr, len) == right_bracket then
            -- addr in [ip:v6] format
            return addr, default_port
        else
            local pos = rfind_char(addr, ":", #addr - 1)
            if not pos or str_byte(addr, pos - 1) ~= right_bracket then
                -- malformed addr
                return addr, default_port
            end

            -- addr in [ip:v6]:port format
            local host = sub_str(addr, 1, pos - 1)
            local port = sub_str(addr, pos + 1)
            return host, tonumber(port)
        end
    else
        -- IPv4 format
        local pos = rfind_char(addr, ":", #addr - 1)
        if not pos then
            return addr, default_port
        end

        local host = sub_str(addr, 1, pos - 1)
        local port = sub_str(addr, pos + 1)
        return host, tonumber(port)
    end
end

return _M

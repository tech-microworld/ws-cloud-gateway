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

-- lua-resty-etcd的封装
-- 文档：https://github.com/api7/lua-resty-etcd/blob/master/api_v3.md#watch
local config = require("app.config")
local etcd = require("resty.etcd")
local error = error

local _M = {version = 1.0}

local etcd_config = config.get_etcd_config()

local function get_prefix()
    return etcd_config.data_prefix
end

_M.get_prefix = get_prefix

local function new()
    if not etcd_config then
        error("can not get etcd config")
    end

    local etcd_connect_config = {
        http_host = etcd_config.http_host,
        protocol = "v3",
        api_prefix = "/v3"
    }

    local prefix = etcd_config.data_prefix
    local etcd_cli, err = etcd.new(etcd_connect_config)
    if not etcd_cli then
        error("can not create etcd client")
    end

    return etcd_cli, prefix, err
end

_M.new = new

function _M.get(key, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:get(prefix .. key, opts)
end

function _M.set(key, value, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:set(prefix .. key, value, opts)
end

-- Set a key-value pair if that key does not exist.
function _M.setnx(key, value, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:setnx(prefix .. key, value, opts)
end

-- Set a key-value pair when that key is exists.
function _M.setx(key, value, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:setx(prefix .. key, value, opts)
end

function _M.delete(key, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:delete(prefix .. key, opts)
end

function _M.watch(key, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:watch(prefix .. key, opts)
end

function _M.readdir(key, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:readdir(prefix .. key, opts)
end

function _M.watchdir(key, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:watchdir(prefix .. key, opts)
end

function _M.rmdir(key, opts)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:rmdir(prefix .. key, opts)
end

function _M.txn(compare, success, failure, opts)
    local etcd_cli, _, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:txn(compare, success, failure, opts)
end

function _M.server_version()
    local etcd_cli, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:version()
end

return _M

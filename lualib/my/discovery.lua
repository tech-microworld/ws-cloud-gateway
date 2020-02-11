local etcd = require("resty.etcd")
local cjson = require "cjson"
local tab_nkeys = require("table.nkeys")
local utils = require("my.utils")
local config = require("my.config")
local discovery_config = config.get("discovery")
local etcd_config = discovery_config.etcd
local service_cache = ngx.shared.discovery_service_cache

local _M = {}

-- 100年，即永不超时
local timeout = 10
local etcd_cli = nil
local delete_type = "DELETE"
local etcd_connect_config = {
    http_host = etcd_config.http_host,
    protocol = "v" .. etcd_config.etcdctl_api,
    api_prefix = etcd_config.api_prefix
}
local etcd_watch_opts = {
    timeout = timeout,
    prev_kv = true,
    start_revision = nil
}

local get_service_name_by_path = function(path)
    local service = nil
    if not path then
        return service
    end
    -- 参数 "j" 启用 JIT 编译，参数 "o" 是开启缓存必须的
    local from, to, err = ngx.re.find(path, "/", "jo")
    if err ~= nil then
        ngx.log(ngx.ERR, "can not get servce name" .. err)
        return service
    end
    if from then
        service = utils.str_sub(path, 1, from - 1)
    else
        service = path
    end
    ngx.log(ngx.INFO, "service: " .. service)
    return service
end

_M.get_service_name_by_path = get_service_name_by_path

-- 查询所有服务节点信息
local get_all_service_nodes = function()
    local service_nodes = {}
    for _, name in ipairs(service_cache:get_keys()) do
        service_nodes[name] = service_cache:get(name)
    end
    ngx.log(ngx.INFO, "service_nodes: " .. cjson.encode(service_nodes))
    return service_nodes
end

_M.get_all_service_nodes = get_all_service_nodes

-- 根据服务名查询节点列表
local function get_service_nodes(service_name)
    local nodes = service_cache:get(service_name)
    if not nodes then
        return nil
    end
    return cjson.decode(nodes)
end

_M.get_service_nodes = get_service_nodes

-- 更新服务节点信息
local function put_service_node(node_data, is_remove)
    if is_remove == nil then
        is_remove = false
    end
    ngx.log(ngx.INFO, "update node: " .. cjson.encode(node_data))
    local path = utils.str_sub(node_data.key, #etcd_config.service_register_path + 2)
    local service_name = get_service_name_by_path(path)
    local service_upstream = utils.str_sub(path, #service_name + 2)
    local weight = node_data.value
    local nodes = get_service_nodes(service_name) or {}
    if is_remove then
        nodes[service_upstream] = nil
    else
        nodes[service_upstream] = weight
    end
    service_cache:set(service_name, cjson.encode(nodes))
end

local function watch_services()
    if 0 == ngx.worker.id() then
        ngx.log(ngx.DEBUG, "worker id is not 0 and do nothing")
        return
    end
    ngx.log(ngx.INFO, "watch start_revision: " .. etcd_watch_opts.start_revision)
    local chunk_fun, err = etcd_cli:watchdir(etcd_config.service_register_path, etcd_watch_opts)

    if not chunk_fun then
        ngx.log(ngx.ERR, "failed to watch: " .. err)
        return
    end
    while true do
        local chunk, err = chunk_fun()
        if not chunk then
            ngx.log(ngx.ERR, "chunk err: " .. err)
            local ok, err = ngx.timer.at(0, watch_services)
            if not ok then
                ngx.log(ngx.ERR, "failed to watch services: ", err)
            end
            break
        end
        etcd_watch_opts.start_revision = chunk.result.header.revision + 1
        if chunk.result.events then
            for _, event in ipairs(chunk.result.events) do
                put_service_node(event.kv, delete_type == event.type)
                get_all_service_nodes()
            end
        end
    end
    ngx.log(ngx.ERR, "watcher exit")
end

-- 加载服务节点注册信息
local function load_services()
    if 0 == ngx.worker.id() then
        ngx.log(ngx.DEBUG, "worker id is not 0 and do nothing")
        return
    end

    local resp, err = etcd_cli:readdir(etcd_config.service_register_path)
    if err ~= nil then
        ngx.log(ngx.ERR, "failed to load services" .. err)
        return
    end

    etcd_watch_opts.start_revision = resp.body.header.revision + 1
    if tab_nkeys(resp.body.kvs) > 0 then
        ngx.log(ngx.ERR, "load services info: " .. cjson.encode(resp.body.kvs))
        for _, node in ipairs(resp.body.kvs) do
            put_service_node(node)
        end
    else
        ngx.log(ngx.INFO, "services info is empty")
    end
end

-- etcd初始化
local function init_etcd()
    local cli, err = etcd.new(etcd_connect_config)
    if not cli then
        ngx.log(ngx.ERR, "create etcd client error: " .. err or "unknown")
        return
    end
    etcd_cli = cli
    load_services()
    get_all_service_nodes()
    watch_services()
    return
end

_M.init = function()
    local ok, err = ngx.timer.at(0, init_etcd)
    if not ok then
        ngx.log(ngx.ERR, "failed to init etcd: ", err)
    end
end

return _M

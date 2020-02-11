local utils = require("my.utils")
local const = require("my.const")
local discovery = require("my.discovery")
local uuid = require 'resty.jit-uuid'


local function create_request_id()
    local req_id = ngx.req.get_headers()[const.HEADER_REQUEST_ID]
    if req_id == nil then
        ngx.req.set_header(const.HEADER_REQUEST_ID, uuid())
    end
end

local function rewrite_uri()
    local path = ngx.var.path
    local uri = ngx.var.uri
    ngx.var.origin_uri = uri


    local service_name = discovery.get_service_name_by_path(path)
    if not service_name then
        ngx.exit(404)
    end

    ngx.var.target_service_name = service_name
    ngx.log(ngx.INFO, "service_name: " .. service_name)

    local target_uri = ""
    path = utils.str_sub(path, #service_name + 1)
    ngx.log(ngx.INFO, "path: " .. path)

    if utils.start_with(uri, const.OPEN_API) then
        target_uri = table.concat({const.OPEN_API, path}, "")
    elseif utils.start_with(uri, const.INNER_API) then
        target_uri = path
    end

    ngx.log(ngx.INFO, "target_uri: " .. target_uri)
    ngx.req.set_uri(target_uri, false)
end

create_request_id()
rewrite_uri()

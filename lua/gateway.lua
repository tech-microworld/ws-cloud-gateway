local discovery = require("my.discovery")
local utils = require("my.utils")

local server_list = {}
local service_name = ngx.var.target_service_name
local list = discovery.get_service_list_by_path(service_name)

if not list then
    ngx.exit(404)
end

for _, v in ipairs(list) do
    server_list[table.concat({v.host, v.port}, ":")] = v.weight
end
ngx.ctx.upstream_server_list = server_list
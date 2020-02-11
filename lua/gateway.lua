local discovery = require("my.discovery")

local service_name = ngx.var.target_service_name
local service_nodes = discovery.get_service_nodes(service_name)

if not service_nodes then
    ngx.exit(404)
end

ngx.ctx.upstream_server_list = service_nodes
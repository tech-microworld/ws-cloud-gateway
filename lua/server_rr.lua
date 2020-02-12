local balancer = require "ngx.balancer"
local resty_roundrobin = require "resty.roundrobin"
local utils = require("my.utils")
local server_list = ngx.ctx.upstream_server_list


ngx.log(ngx.INFO, "server list: " .. utils.table_to_string(server_list));
local rr_up = resty_roundrobin:new(server_list)
local server = rr_up:find()
balancer.set_current_peer(server)


local etcd = require("resty.etcd")

ngx.log(ngx.ERR, "init worker.......");

local cli, err = etcd.new({protocol = "v2", api_prefix = "3.4."})
ngx.log(ngx.ERR, "etcd cli: " .. type(cli.watchdir));
if err ~= nil then
    ngx.log(ngx.ERR, "etcd error: " .. err or "unkonw");
end

local res, err = cli:watchdir('/micros/service')
ngx.log(ngx.ERR, "watchdir: " .. type(res));

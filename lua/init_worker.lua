local etcd = require("resty.etcd")
local cjson = require("cjson")
local discovery = require("my.discovery")
local worker_id = ngx.worker.id()

ngx.log(ngx.INFO, "init worker: " .. worker_id)

discovery.init()


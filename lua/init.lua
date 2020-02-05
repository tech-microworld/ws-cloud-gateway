local config = require("my.config")


-- 加载配置文件
config.load(ngx.config.prefix() .. "lua/conf.json")




local config = require("my.config")
local uuid = require("resty.jit-uuid")

-- 加载配置文件
config.load(ngx.config.prefix() .. "lua/conf.json")
-- automatic seeding with os.time(), LuaSocket, or ngx.time()
uuid.seed() 







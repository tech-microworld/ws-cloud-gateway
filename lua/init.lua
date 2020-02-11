local config = require("my.config")
local uuid = require("resty.jit-uuid")

-- 加载配置文件
local env = os.getenv("resty.env")
config.init(env)
-- automatic seeding with os.time(), LuaSocket, or ngx.time()
uuid.seed() 







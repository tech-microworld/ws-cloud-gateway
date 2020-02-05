local const = require("my.const")
local config = require("my.config")

local _M = {}

_M.get_service_name_by_path = function(path)
    local service = nil
    if not path then
        return service
    end    
    -- 参数 "j" 启用 JIT 编译，参数 "o" 是开启缓存必须的
    local from, to, err = ngx.re.find(path, "/", "jo")
    if from then
        service = string.sub(path, 1, from - 1)
    else
        service = path
    end
    return service
end

_M.get_service_list_by_path = function(service_name)
    local discovery = config.get(const.DISCOVERY)
    local list = discovery[service_name]
    if not list then
        ngx.log(ngx.ERR, "discovery none server list for: " .. service)
    end
    return list
end

return _M

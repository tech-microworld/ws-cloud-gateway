local ngx = ngx
local now = ngx.now
local update_time = ngx.update_time


local _M = {}

function _M.now()
    update_time()
    return now()
end


return _M
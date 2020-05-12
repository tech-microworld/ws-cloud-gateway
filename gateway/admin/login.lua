

local function login()
    return true
end

local _M = {
    apis = {
        {
            paths = {[[/admin/login]]},
            methods = {"POST"},
            handler = login
        }
    }
}

return _M
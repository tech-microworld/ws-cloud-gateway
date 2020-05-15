
local ctx = require("app.core.ctx")
local core_table = require("app.core.table")
local resp = require("app.core.response")
local pairs = pairs

local function list()
    local plugins_list = {}
    local plugins = ctx.plugins()
    for _, p in pairs(plugins) do
        if p.optional then
            core_table.insert(plugins_list, {
                name = p.name,
                desc = p.desc .. "_" .. p.version
            })
        end
    end
    resp.exit(ngx.OK, plugins_list)
end

local _M = {
    apis = {
        {
            paths = {[[/admin/plugins/list]]},
            methods = {"GET", "POST"},
            handler = list
        }
    }
}

return _M

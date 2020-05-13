local cjson = require("cjson")
local jwt = require "resty.jwt"
local ngx = ngx
local now = ngx.now
local update_time = ngx.update_time
local config_get = require("app.config").get
local resp = require("app.core.response")
local log = require("app.core.log")

local function login()
    local jwt_secret = config_get("admin").jwt_secret
    local account = config_get("admin").account
    local body = ngx.req.get_body_data()
    if not body then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "用户名或密码为空")
    end

    local data = cjson.decode(ngx.req.get_body_data())

    if not data or not data.username or not data.password then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "用户名或密码为空")
    end

    local user = account[data.username]
    if not user or user.password ~= data.password then
        resp.exit(ngx.HTTP_INTERNAL_SERVER_ERROR, "用户名或密码错误")
    end

    update_time()
    local token = jwt:sign(
        jwt_secret,
        {
            header = {typ = "JWT", alg = "HS256"},
            payload = {
                exp = now() + 7 * 24 * 60 + 60,
                username = data.username
            }
        }
    )
    resp.exit(ngx.OK, {token = token})
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

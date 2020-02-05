local cjson = require "cjson"

local _M = {}

local str_sub = function(str, start, ending)
    if not ending then
        ending = #str
    end
    return string.char(string.byte(str, start, ending))
end

_M.str_sub = str_sub

_M.start_with = function(str, start)
    return str_sub(str, 1, #start) == start
end

_M.end_with = function(str, ending)
    return ending == "" or str_sub(str, -(#ending)) == ending
end

_M.table_to_string = function(t)
    return cjson.encode(t)
end

return _M

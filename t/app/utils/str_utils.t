
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::BASE 'no_plan';

run_tests();

__DATA__

=== TEST 1: test substr_before_last
--- config
    location = /t {
        content_by_lua_block {
            local str_utils = require("app.utils.str_utils")
            local str = ngx.var.arg_str
            ngx.say(str_utils.substr_before_last(str, "/"))
        }
    }
--- request
GET /t?str=/open/api/user/info
--- response_body
/open/api/user


=== TEST 2: test last_index_of
--- config
    location = /t {
        content_by_lua_block {
            local str_utils = require("app.utils.str_utils")
            local str = ngx.var.arg_str
            ngx.say(str_utils.last_index_of(str, "/"))
        }
    }
--- request
GET /t?str=/open/api/user/info
--- response_body
15

=== TEST 3: test substr_after_last
--- config
    location = /t {
        content_by_lua_block {
            local str_utils = require("app.utils.str_utils")
            local str = ngx.var.arg_str
            ngx.say(str_utils.substr_after_last(str, "/"))
        }
    }
--- request
GET /t?str=/open/api/user
--- response_body
user

=== TEST 4: test trim
--- config
    location = /t {
        content_by_lua_block {
            local str_utils = require("app.utils.str_utils")
            local log = require("app.core.log")
            local str = ngx.req.get_uri_args().str
            ngx.print(str_utils.trim(str))
        }
    }
--- pipelined_requests eval
[
    "GET /t?str=%20%20%20aa%20",
    "GET /t?str=%20%20"
]
--- response_body eval
['aa', '']

=== TEST 5: test is_blank
--- config
    location = /t {
        content_by_lua_block {
            local str_utils = require("app.utils.str_utils")
            local str = ngx.req.get_uri_args().str
            ngx.print(str_utils.is_blank(str))
        }
    }
--- pipelined_requests eval
[
    "GET /t?str=%20aa%20",
    "GET /t?str=%20%20"
]

--- response_body eval
['false', 'true']


=== TEST 6: test split
--- config
    location = /t {
        content_by_lua_block {
            local str_utils = require("app.utils.str_utils")
            local log = require("app.core.log")

            local str = ngx.req.get_uri_args().str
            local t = str_utils.split(str, ",")
            ngx.print(table.concat(t, " "))
        }
    }
--- request
GET /t?str=a%2Cb%2Cc%2Cd

--- response_body eval
['a b c d']

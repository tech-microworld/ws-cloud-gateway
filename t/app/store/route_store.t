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
use t::CONFIG 'no_plan';

run_tests();

__DATA__

=== TEST 1: test etcd
--- config
    location = /save {
        content_by_lua_block {
            local cjson = require "cjson"
            local log = require("app.core.log")
            local route_store = require("app.store.route_store")

            ngx.req.read_body()
            local data = ngx.req.get_body_data()
            local route = cjson.decode(data)
            local err = route_store.save_route(route)
            check_res("ok", err, true)
        }
    }

    location = /query {
        content_by_lua_block {
            local cjson = require "cjson"
            local log = require("app.core.log")
            local router = require("app.core.router")

            local url = ngx.var.arg_url
            local route = router.match(url)
            check_res(route and  route.prefix or "", nil, true)
        }
    }

    location = /delete {
        content_by_lua_block {
            local cjson = require "cjson"
            local log = require("app.core.log")
            local route_store = require("app.store.route_store")

            local route_prefix = ngx.var.arg_prefix
            local err = route_store.remove_route(route_prefix)
            check_res("ok", err, true)
        }
    }

--- pipelined_requests eval
[
    'POST /save
    {
        "prefix": "/openapi/demo/*",
        "status": 1,
        "service_name": "demo",
        "protocol": "http",
        "plugins": [
            "discovery",
            "tracing"
        ],
        "props": {
        }
    }
    ',
    'GET /query?url=/openapi/demo/info',
    'POST /save
    {
        "key": "/openapi/demo/*",
        "prefix": "/openapi/demo/*",
        "status": 0,
        "service_name": "demo",
        "protocol": "http",
        "plugins": [
            "discovery",
            "tracing"
        ],
        "props": {
        }
    }
    ',
    'GET /query?url=/openapi/demo/info',
    'DELETE /delete?prefix=/openapi/demo/*'
]

--- response_body eval
[
    "ok\n",
    "/openapi/demo/*\n",
    "ok\n",
    "\n",
    "ok\n"
]

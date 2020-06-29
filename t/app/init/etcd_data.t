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

=== TEST 1: init route
--- config
location = /t {
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

--- pipelined_requests eval
[
    'POST /t
    {
        "prefix": "/openapi/demo1",
        "status": 1,
        "service_name": "demo1",
        "protocol": "http",
        "plugins": [
            "discovery",
            "tracing",
            "rewrite"
        ],
        "props": {
            "rewrite_url_regex" : "^/openapi/(.*)/",
            "rewrite_replace" : "/openapi/"
        }
    }
    ',
    'POST /t
    {
        "prefix": "/innerapi/demo1",
        "status": 1,
        "service_name": "demo1",
        "protocol": "http",
        "plugins": [
            "discovery",
            "tracing",
            "rewrite"
        ],
        "props": {
            "rewrite_url_regex" : "^/innerapi/(.*)/",
            "rewrite_replace" : "/"
        }
    }
    ',
    'POST /t
    {
        "prefix": "/openapi/demo2",
        "status": 1,
        "service_name": "demo2",
        "protocol": "http",
        "plugins": [
            "discovery",
            "tracing"
        ],
        "props": {
        }
    }
    ',
    'POST /t
    {
        "prefix": "/hello.GreeterService",
        "status": 1,
        "service_name": "grpc-demo",
        "protocol": "grpc",
        "plugins": [
            "discovery",
            "tracing"
        ],
        "props": {
        }
    }
    '

    
]

--- response_body eval
[
    "ok\n",
    "ok\n",
    "ok\n",
    "ok\n"
]


=== TEST 2: init discovery
--- config
    location = /t {
        content_by_lua_block {
            local cjson = require "cjson"
            local log = require("app.core.log")
            local discovery_stroe = require("app.store.discovery_stroe")

            ngx.req.read_body()
            local nodes = cjson.decode(ngx.req.get_body_data())
            for _, node in ipairs(nodes) do
                log.error("save node: ", cjson.encode(node))
                discovery_stroe.set_service_node(node)
            end

            check_res("ok", nil, true)
        }
    }

--- request
POST /t
[
    {
        "service_name": "demo1",
        "upstream": "127.0.0.1:1024",
        "weight": 1,
        "status": 1
    },
    {
        "service_name": "demo1",
        "upstream": "127.0.0.1:1025",
        "weight": 1,
        "status": 1
    },
    {
        "service_name": "demo2",
        "upstream": "127.0.0.1:1026",
        "weight": 1,
        "status": 1
    },
    {
        "service_name": "demo2",
        "upstream": "127.0.0.1:1027",
        "weight": 1,
        "status": 1
    },
    {
        "service_name": "grpc-demo",
        "upstream": "127.0.0.1:2021",
        "weight": 1,
        "status": 1
    }
]

--- response_body
ok

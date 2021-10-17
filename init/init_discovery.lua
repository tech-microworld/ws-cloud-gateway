--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local app = require("app.init")
-- init
do
    app.http_init()
end -- end do

local os = os
local ngx = ngx
local ipairs = ipairs
local json = require("app.core.json")
local discovery_stroe = require("app.store.discovery_stroe")

local data_file = os.getenv("BASE_DIR") .. "/init/init_discovery.json"
ngx.say("load data: " .. data_file)
local datas = json.decode_json_file(data_file)

for _, node in ipairs(datas) do
    ngx.say("set_service_node: " .. json.encode(node))
    discovery_stroe.set_service_node(node)
end

ngx.say("init discovery")

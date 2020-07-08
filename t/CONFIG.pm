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
package t::CONFIG;

use lib 'lib';
use Cwd qw(cwd);
# use Test::Nginx::Socket -Base;
use Test::Nginx::Socket::Lua -Base;
use URI::Escape;

log_level('debug');
no_long_string();
no_root_location();
no_shuffle();
worker_connections(128);

my $app_home = cwd();
my $config_file = $ENV{'gateway_config_file'} || "$app_home/conf/app.json";

add_block_preprocessor(sub {
    # my $block = shift;
    my ($block) = @_;

    my $http_config = $block->http_config // <<_EOC_;

    error_log logs/error.log debug;

    # 全局缓存定义
    lua_shared_dict upstream_type_cache 100k;
    lua_shared_dict timer_lock 100k;
    lua_shared_dict lrucache_lock 100k;


    lua_package_path "$app_home/deps/share/lua/5.1/?.lua;$app_home/deps/share/lua/5.1/?/init.lua;$app_home/gateway/?.lua;$app_home/gateway/?/init.lua;$app_home/t/?.lua;;";
    lua_package_cpath "$app_home/deps/lib64/lua/5.1/?.so;$app_home/deps/lib/lua/5.1/?.so;;";

    init_by_lua_block {
        local config = require("app.config")

        -- 加载配置文件
        config.init("$config_file")

        function check_res(data, err, say)
            if err then
                ngx.say("err: ", err)
                ngx.exit(500)
            end

            if say then
                ngx.say(data)
                ngx.exit(200)
            end
        end

    }
_EOC_
    $block->set_value("http_config", $http_config);


    my $config = $block->config // <<_EOC_;
    location = /app-name {
        content_by_lua_block {
            local config = require("app.config")
            ngx.print(config.get("appName"))
        }
    }
_EOC_
    $block->set_value("config", $config);

});

1;

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
package t::GATEWAY;

use Cwd qw(cwd);
# use Test::Nginx::Socket -Base;
use Test::Nginx::Socket::Lua -Base;
use URI::Escape;

log_level('debug');
no_long_string();
no_root_location();

my $app_home = cwd();
my $config_file = $ENV{'gateway_config_file'} || "$app_home/conf/app.json";

add_block_preprocessor(sub {
    # my $block = shift;
    my ($block) = @_;

    my $main_config = $block->main_config // <<_EOC_;

    env gateway_config_file=${config_file};

_EOC_

    $block->set_value("main_config", $main_config);

    my $http_config = $block->http_config // <<_EOC_;

    error_log logs/error.log debug;

    include ${app_home}/conf/mime.types;

    sendfile        on;
    #tcp_nopush     on;

    # 避免正则回溯问题
    lua_regex_match_limit 100000;

    # 全局缓存定义
    lua_shared_dict upstream_type_cache 1m;
    lua_shared_dict timer_lock 1m;
    lua_shared_dict lrucache_lock 1m;

    #最大等待任务数
    lua_max_pending_timers 1024;
    #最大同时运行任务数
    lua_max_running_timers 256;


    #lua库依赖路径
    lua_package_path "$app_home/deps/share/lua/5.1/?.lua;$app_home/deps/share/lua/5.1/?/init.lua;$app_home/gateway/?.lua;$app_home/gateway/?/init.lua;$app_home/t/?.lua;;";
    lua_package_cpath "$app_home/deps/lib64/lua/5.1/?.so;$app_home/deps/lib/lua/5.1/?.so;;";

    #初始化脚本
    init_by_lua_block {
        local app = require("app")
        app.http_init()

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

    init_worker_by_lua_block {
        local app = require("app")
        app.http_init_worker()
    }

    upstream backend_server {
        # just an invalid address as a place holder
        server 0.0.0.0;
        balancer_by_lua_block {
            local app = require("app")
            app.http_balancer()
        }
        # connection pool
        keepalive 100;
        keepalive_timeout 60s;
    }

    include ${app_home}/conf/servers/demo.conf;

_EOC_
    $block->set_value("http_config", $http_config);

    my $config = $block->config // <<_EOC_;

    location / {
        include common/proxy.conf;
        set \$target_service_name '';
        set \$origin_uri \$uri;
        lua_code_cache on;
        rewrite_by_lua_block {
            local app = require("app")
            app.http_rewrite()
        }
        access_by_lua_block {
            local app = require("app")
            app.http_rewrite()
        }
        content_by_lua_block {
            local app = require("app")
            app.http_content()
        }
        header_filter_by_lua_block {
            local app = require("app")
            app.http_header_filter()
        }
        body_filter_by_lua_block {
            local app = require("app")
            app.http_body_filter()
        }
        log_by_lua_block {
            local app = require("app")
            app.http_log()
        }

        proxy_pass http://backend_server;
    }


_EOC_
    $block->set_value("config", $config);

});

1;

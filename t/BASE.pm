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
package t::BASE;

use Cwd qw(cwd);
use Test::Nginx::Socket::Lua -Base;
use URI::Escape;

log_level('debug');
no_long_string();
no_root_location();

my $app_home = cwd();

add_block_preprocessor(sub {
    # my $block = shift;
    my ($block) = @_;

    my $http_config = $block->http_config // <<_EOC_;
    lua_package_path "$app_home/deps/share/lua/5.1/?.lua;$app_home/deps/share/lua/5.1/?/init.lua;$app_home/gateway/?.lua;$app_home/t/?.lua;;";
    lua_package_cpath "$app_home/deps/lib64/lua/5.1/?.so;$app_home/deps/lib/lua/5.1/?.so;;";
_EOC_
    $block->set_value("http_config", $http_config);

});

1;

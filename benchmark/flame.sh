#! /bin/bash -x

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


home=$(dirname $(pwd))

echo $home

stapxx_home=$home/.travis/stapxx
flame_graph_home=$home/.travis/FlameGraph
toolkit_home=$home/.travis/openresty-systemtap-toolkit

export PATH=${stapxx_home}:${flame_graph_home}:${toolkit_home}:$PATH

pid=$(ps -ef | grep nginx | grep 'worker process' | awk 'NR==1{print $2}')

out=out

mkdir -p $out

$stapxx_home/samples/lj-lua-stacks.sxx --arg time=5  --skip-badvars -x $pid > $out/tmp.bt
# 处理 lj-lua-stacks.sxx 的输出，使其可读性更佳
$toolkit_home/fix-lua-bt $out/tmp.bt > $out/flame.bt

$flame_graph_home/stackcollapse-stap.pl $out/flame.bt > $out/flame.cbt

$flame_graph_home/flamegraph.pl --encoding="ISO-8859-1" \
              --title="Lua-land on-CPU flamegraph" \
              $out/flame.cbt > $out/flame.svg


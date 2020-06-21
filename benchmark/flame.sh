#! /bin/bash

home=$(dirname $(pwd))

echo $home

stapxx_home=$home/.travis/stapxx
flame_graph_home=$home/.travis/FlameGraph
toolkit_home=$home/.travis/openresty-systemtap-toolkit

pid=$(ps x | grep nginx | grep 'worker process' | awk 'NR==1{print $1}')

out=out

$stapxx_home/samples/lj-lua-stacks.sxx --arg time=5  --skip-badvars -x $pid > $out/tmp.bt
# 处理 lj-lua-stacks.sxx 的输出，使其可读性更佳
$toolkit_home/fix-lua-bt $out/tmp.bt > $out/flame.bt

$flame_graph_home/stackcollapse-stap.pl $out/flame.bt > $out/flame.cbt

$flame_graph_home/flamegraph.pl --encoding="ISO-8859-1" \
              --title="Lua-land on-CPU flamegraph" \
              $out/flame.cbt > $out/flame.svg


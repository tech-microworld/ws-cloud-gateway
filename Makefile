gateway_config_file ?= conf/app.json
export BASE_DIR := $(shell pwd)
export gateway_config_file := ${BASE_DIR}/${gateway_config_file}
OR_EXEC ?= $(shell which openresty)
LUAROCKS_VER ?= $(shell luarocks --version | grep -E -o  "luarocks [0-9]+.")

.PHONY: default
default:
ifeq ($(OR_EXEC), )
ifeq ("$(wildcard /usr/local/openresty-debug/bin/openresty)", "")
	@echo "ERROR: OpenResty not found. You have to install OpenResty and add the binary file to PATH"
	exit 1
endif
endif

LUAJIT_DIR ?= $(shell ${OR_EXEC} -V 2>&1 | grep prefix | grep -Eo 'prefix=(.*)/nginx\s+--' | grep -Eo '/.*/')luajit

verify: lint license-check test
### benchmark:			执行压力测试
benchmark: start-background demo-server-start benchmark-wrk demo-server-stop stop

.PHONY: init
### init:				初始化数据
init: default
	@resty --errlog-level=error \
	-I=./gateway \
	-I=./gateway/app/init.lua \
	-I=./deps/share/lua/5.1 \
	-I=./deps/lib/lua/5.1 \
	-I=./deps/lib64/lua/5.1 \
	init/init_route.lua

	@resty --errlog-level=error \
	-I=./gateway \
	-I=./gateway/app/init.lua \
	-I=./deps/share/lua/5.1 \
	-I=./deps/lib/lua/5.1 \
	-I=./deps/lib64/lua/5.1 \
	init/init_discovery.lua

### clean:				清理数据&日志
clean: default
	rm -rf logs/*.log
	@resty --errlog-level=error \
	-I=./gateway \
	-I=./gateway/app/init.lua \
	-I=./deps/share/lua/5.1 \
	-I=./deps/lib/lua/5.1 \
	-I=./deps/lib64/lua/5.1 \
	init/clean.lua

### start:				启动服务
start: default
	@echo "server start"
	@nginx -p `pwd` -c conf/nginx.conf -g 'daemon off;'

### start-background:			后台启动服务
start-background: default
	@echo "server start"
	@nginx -p `pwd` -c conf/nginx.conf

### stop:				停止服务
stop: default
	@echo "server stop"
	@nginx -p `pwd` -c conf/nginx.conf -s stop

### demo-server-start:			启动测试服务
demo-server-start: default
	@echo "demo server start"
	@mkdir -p `pwd`/benchmark/server/logs
	nginx -p `pwd`/benchmark/server -c conf/nginx.conf

### demo-server-stop:			停止测试服务
demo-server-stop: default
	@echo "demo server stop"
	nginx -p `pwd`/benchmark/server -c conf/nginx.conf -s stop

### deps:				安装依赖
.PHONY: deps
deps: default
ifeq ($(LUAROCKS_VER),luarocks 3.)
	luarocks install --lua-dir=$(LUAJIT_DIR) rockspec/ws-cloud-gateway-master-0.rockspec --tree=deps --only-deps --local
else
	luarocks install rockspec/ws-cloud-gateway-master-0.rockspec --tree=deps --only-deps --local
endif

### test:				执行测试用例
.PHONY: test
test:
	@prove -I./ -r -s t/

test-store:
	@prove -I./ -r -s t/app/store

test-utils:
	@prove -I./ -r -s t/app/utils

test-core:
	@prove -I./ -r -s t/app/core


### utils:				安装lj-releng
.PHONY: utils
utils:
ifeq ("$(wildcard bin/lj-releng)", "")
	wget -O bin/lj-releng https://raw.githubusercontent.com/iresty/openresty-devel-utils/master/lj-releng
	chmod a+x bin/lj-releng
endif

### lint:				代码风格检查
.PHONY: lint
lint: utils
	./bin/check-lua-code-style.sh

### help:				Makefile帮助
.PHONY: help
help: default
	@echo Makefile cmd:
	@echo
	@grep -E '^### [-A-Za-z0-9_]+:' Makefile | sed 's/###/   /'


.PHONY: license-tool
### license-tool:			安装源码检测工具 openwhisk-utilities，校验license header
license-tool:
ifeq ("$(wildcard .travis/openwhisk-utilities/scancode/scanCode.py)", "")
	git clone https://github.com/tech-microworld/openwhisk-utilities.git .travis/openwhisk-utilities
	cp .travis/ASF* .travis/openwhisk-utilities/scancode/
endif

### license-check:			源码检查是否包含 license header
license-check: license-tool
	.travis/openwhisk-utilities/scancode/scanCode.py --config .travis/ASF-Release.cfg .

### license-header:			自动给源码增加 license header
license-header: license-tool
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./gateway -f '*.lua' -t ASFLicenseHeaderLua.txt
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./init -f '*.lua' -t ASFLicenseHeaderLua.txt
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./t -f '*.pm' -t ASFLicenseHeaderBash.txt
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./t -f '*.t' -t ASFLicenseHeaderBash.txt
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./bin -f '*.sh' -t ASFLicenseHeaderBash.txt
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./benchmark -f '*.sh' -t ASFLicenseHeaderBash.txt

.PHONY: benchmark
### benchmark-tool:			安装 benchmark 工具
benchmark-tool:
ifeq ("$(wildcard .travis/stapxx/samples/lj-lua-stacks.sxx)", "")
	git clone https://github.com/openresty/stapxx.git .travis/stapxx
endif
ifeq ("$(wildcard .travis/FlameGraph/flamegraph.pl)", "")
	git clone https://github.com/brendangregg/FlameGraph.git .travis/FlameGraph
endif
ifeq ("$(wildcard .travis/openresty-systemtap-toolkit/fix-lua-bt)", "")
	git clone https://github.com/openresty/openresty-systemtap-toolkit.git .travis/openresty-systemtap-toolkit
endif

### benchmark-wrk:			wrk 压力测试
benchmark-wrk: benchmark-tool
	@cd benchmark && sh run-wrk.sh

### benchmark-flame:			绘制火焰图
benchmark-flame: benchmark-tool
	@cd benchmark && sh flame.sh

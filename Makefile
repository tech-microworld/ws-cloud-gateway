export gateway_config_file=conf/app-dev.json
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

### init:			初始化
.PHONY: init
init: default
	@prove -I./ -r -s t/app/init

### start:			启动服务
start: default
	@echo "server start"
	@openresty -p `pwd` -c conf/nginx.conf -g 'daemon off;'

### deps:			安装依赖
.PHONY: deps
deps: default
ifeq ($(LUAROCKS_VER),luarocks 3.)
	luarocks install --lua-dir=$(LUAJIT_DIR) rockspec/my-cloud-gateway-dev-0.rockspec --tree=deps --only-deps --local
else
	luarocks install rockspec/my-cloud-gateway-dev-0.rockspec --tree=deps --only-deps --local
endif

### test:			执行测试用例
.PHONY: test
test:
	@prove -I./ -r -s t

test-store:
	@prove -I./ -r -s t/app/store

test-utils:
	@prove -I./ -r -s t/app/utils

test-core:
	@prove -I./ -r -s t/app/core


### utils:			安装lj-releng
.PHONY: utils
utils:
ifeq ("$(wildcard bin/lj-releng)", "")
	wget -O bin/lj-releng https://raw.githubusercontent.com/iresty/openresty-devel-utils/master/lj-releng
	chmod a+x bin/lj-releng
endif

### lint:			代码风格检查
.PHONY: lint
lint: utils
	./bin/check-lua-code-style.sh


### help: 			Makefile帮助
.PHONY: help
help: default
	@echo Makefile cmd:
	@echo
	@grep -E '^### [-A-Za-z0-9_]+:' Makefile | sed 's/###/   /'


.PHONY: license-tool
### license-tool:		安装源码检测工具 openwhisk-utilities，校验license header
license-tool:
ifeq ("$(wildcard .travis/openwhisk-utilities/scancode/scanCode.py)", "")
	git clone https://github.com/tech-microworld/openwhisk-utilities.git .travis/openwhisk-utilities
	cp .travis/ASF* .travis/openwhisk-utilities/scancode/
endif

### license-check:		源码检查是否包含 license header
license-check: license-tool
	.travis/openwhisk-utilities/scancode/scanCode.py --config .travis/ASF-Release.cfg .

### license-header:		自动给源码增加 license header
license-header: license-tool
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./gateway -f '*.lua' -t ASFLicenseHeaderLua.txt
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./t -f '*.pm' -t ASFLicenseHeaderBash.txt
	sh .travis/openwhisk-utilities/scancode/add-license-header.sh -d ./t -f '*.t' -t ASFLicenseHeaderBash.txt

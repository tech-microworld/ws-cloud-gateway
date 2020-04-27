# resty-gateway

github: <https://github.com/fengjx/resty-gateway>

基于openresty + etcd实现的网关服务

### 依赖

- [resty.roundrobin](https://github.com/openresty/lua-resty-balancer/blob/master/lib/resty/roundrobin.lua)
- [lua-resty-jit-uuid](https://github.com/thibaultCha/lua-resty-jit-uuid)
- [lua-resty-etcd](https://github.com/iresty/lua-resty-etcd)
- [lua-resty-http](https://github.com/ledgetech/lua-resty-http)
- [lua-typeof](https://github.com/iresty/lua-typeof)

### 整体架构

![整体架构](/res/resty-gateway.jpg)

服务启动时，将自己的节点信息注册到etcd，包括：服务名称、ip、端口

网关服务从etcd监听服务节点信息，保存到缓存中，从客户端请求的url中提取服务名称，通过服务名称查找节点信息，将请求转发到后端服务


### todo

- [x] 服务发现，动态路由
- [x] 自动生成requestId，方便链路跟踪
- [ ] 动态ip防火墙
- [ ] 限流器
- [ ] 用户登录认证
- [ ] 接口协议加解密

### 文档

详细文档查看：<https://blog.fengjx.com/openresty/gateway.html>


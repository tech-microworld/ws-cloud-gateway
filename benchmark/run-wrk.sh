#! /bin/bash -x

token=e09d6153f1c15395397be3639d144794

make start-background || exit 1

sleep 3

echo 'server started'

curl http://127.0.0.1:10000/admin/routes/save -H "X-API-TOKEN: ${token}" -X POST -d '
{
    "key": "/innerapi/hello",
    "protocol": "http",
    "remark": "",
    "prefix": "/innerapi/hello",
    "service_name": "hello",
    "status": 1,
    "plugins": [
        "discovery",
        "tracing",
        "rewrite"
    ],
    "props": {
        "rewrite_url_regex": "^/innerapi/(.*)/",
        "rewrite_replace": "/"
    }
}'

curl http://127.0.0.1:10000/admin/services/save -H "X-API-TOKEN: ${token}" -X POST -d '
{
    "key": "/hello/127.0.0.1:1024",
    "service_name": "hello",
    "upstream": "127.0.0.1:1024",
    "weight": 1,
    "status": 1
}'

sleep 1

wrk -c100 -t10 -d10s http://127.0.0.1:10000/innerapi/hello

make stop || exit 1
echo 'end'
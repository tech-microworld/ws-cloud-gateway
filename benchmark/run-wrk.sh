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

sleep 1

token=e09d6153f1c15395397be3639d144794

curl http://127.0.0.1:10000/admin/routes/save -H "X-Api-Token: ${token}" -X POST -d '
{
    "key": "/innerapi/hello/*",
    "protocol": "http",
    "remark": "",
    "prefix": "/innerapi/hello/*",
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

echo

curl http://127.0.0.1:10000/admin/services/save -H "X-Api-Token: ${token}" -X POST -d '
{
    "key": "/hello/127.0.0.1:8080",
    "service_name": "hello",
    "upstream": "127.0.0.1:8080",
    "weight": 1,
    "status": 1
}'

echo

sleep 2
echo 'benchmark start'

mkdir -p out
wrk -d 5 -c 16 --latency http://127.0.0.1:10000/innerapi/hello/api > out/wrk.out

cat out/wrk.out
echo 'benchmark end'

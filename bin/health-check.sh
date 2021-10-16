#!/usr/bin/env bash

url="http://localhost:10000/egg/"

i=0
while [ true ]; do
    curl -s -w '%{http_code}' -o /dev/null ${url}
    let "i++"
    echo " $i"
    sleep 0.2
done

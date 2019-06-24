#!/bin/bash

script_dir_path="$(cd "$(dirname "$0")" && pwd)"

"${script_dir_path}/../node_modules/.bin/ganache-cli" \
    --accounts=300 \
    --defaultBalanceEther=10000 \
    --gasLimit 0xfffffffffff

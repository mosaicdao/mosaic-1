#!/bin/bash

docker run --name mosaic-dev -p 8545:8545 -p 8546:8546 -p 30303:30303 mosaicdao/dev-chains:1.0.3 origin &
sleep 25
truffle exec ../test_dist/test_integration/erc20_gateway/integration_tests.js --network integration
TEST_STATUS=$?
rm -rf ../test_dist/
docker stop mosaic-dev
docker rm mosaic-dev
exit $TEST_STATUS



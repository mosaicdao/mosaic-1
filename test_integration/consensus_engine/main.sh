#!/bin/bash

echo 'Ganache-cli is pre-requisite for integration tests'
echo ' Run command: "npm run ganache-cli" if ganache is not running already'
truffle exec ./dist/test_integration/integration_tests.js
TEST_STATUS=$?
rm -rf ./dist
exit $TEST_STATUS



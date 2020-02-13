pragma solidity >=0.5.0 <0.6.0;

// Copyright 2020 OpenST Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/**
 * @title Observer Interface
 */
interface ObserverInterface {

    /**
     * @notice setup() function initializes the observer contract.
     */
     function setup() external;

    /**
     * @notice Anchor the state root for an (increasing) block number.
     *
     * @param _blockNumber Block number for which state root needs to
     *                      update.
     * @param _stateRoot State root of input block number.
     */
    function anchorStateRoot(
        uint256 _blockNumber,
        bytes32 _stateRoot
    )
        external;
}

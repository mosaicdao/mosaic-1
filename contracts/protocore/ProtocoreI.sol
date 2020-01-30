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
 * @title Protocore Interface
 */
interface ProtocoreI {

    /** @notice setup() function initializes the protocore contract. */
    function setup() external;

    /** @notice Function to get the domain separator. */
    function domainSeparator() external returns (bytes32);

    /**
     * @notice Function to return the metablock height, block number
     *         and block hash of the finalized checkpoint.
     */
    function latestFinalizedBlock()
        external
        view
        returns (
            uint256 metablockHeight_,
            uint256 blockNumber_,
            bytes32 blockHash_
        );

    /**
     * @notice Function to get the current dynasty.
     */
     function currentDynasty() external view returns (uint256);
}

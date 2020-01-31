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

    /**
     * @notice setup() function initializes the protocore contract.
     *
     * @param _metachainId Metachain id.
     * @param _domainSeparator Domain separator.
     * @param _epochLength Epoch length.
     * @param _metablockHeight Metablock height.
     */
    function setup(
        bytes32 _metachainId,
        bytes32 _domainSeparator,
        uint256 _epochLength,
        uint256 _metablockHeight
    )
        external;

    function openKernelHeight()
        external
        returns (uint256);

    function openKernel(
        uint256 _kernelHeight,
        bytes32 _kernelHash
    )
        external;
}

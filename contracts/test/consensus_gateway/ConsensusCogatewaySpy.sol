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

import "../../consensus-gateway/ConsensusCogatewayInterface.sol";

contract ConsensusCogatewaySpy is ConsensusCogatewayInterface {

    mapping(uint256 => bytes32) public testKernelHashes;

    uint256 public spyKernelHeight;

    /**
     * @notice Set the kernel hash for a given kernel height. For testing only.
     */
    function setKernelHash(
        bytes32 _kernelHash,
        uint256 _kernelHeight
    )
        external
    {
        testKernelHashes[_kernelHeight] = _kernelHash;
    }

    /**
     * @notice Get the kernel hash for a given kernel height. For testing only.
     */
    function getKernelHash(uint256 _kernelHeight)
        external
        returns (bytes32 kernelHash_)
    {
        spyKernelHeight = _kernelHeight;
        return testKernelHashes[_kernelHeight];
    }
}

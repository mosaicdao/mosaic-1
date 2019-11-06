pragma solidity >=0.5.0 <0.6.0;

// Copyright 2019 OpenST Ltd.
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

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract KernelBase {

    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /** EIP-712 type hash for Kernel. */
    bytes32 public constant KERNEL_TYPEHASH = keccak256(
        "Kernel(uint256 height,bytes32 parent,address[] updatedValidators,uint256[] updatedReputation,uint256 gasTarget)"
    );


    /* Variables */

    /** Chain identifier */
    bytes20 public chainId;

    /** Nonce count for the consensus address */
    uint256 public nonce;

    /** Latest kernel height */
    uint256 public latestKernelHeight;

    /** Latest gas target */
    uint256 public latestGasTarget;

    /** Mapping of kernel intent hash to kernel message hash */
    mapping(bytes32 => bytes32) public kernelMessages;

    /* Internal Functions */


    function kernelTypeHash(
        uint256 _height,
        bytes32 _parent,
        address[] memory _updatedValidators,
        uint256[] memory _updatedReputation,
        uint256 _gasTarget

    )
        internal
        pure
        returns (bytes32 kernelTypeHash_)
    {
        kernelTypeHash_ = keccak256(
            abi.encode(
                KERNEL_TYPEHASH,
                _height,
                _parent,
                _updatedValidators,
                _updatedReputation,
                _gasTarget
            )
        );
    }
}

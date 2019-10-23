pragma solidity ^0.5.0;

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

import "../../Core/Core.sol";

contract MockCore is Core {

    /* Special Functions */

    constructor(
        bytes20 _chainId,
        uint256 _epochLength,
        uint256 _minValidators,
        uint256 _joinLimit,
        ReputationI _reputation,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _source,
        uint256 _sourceBlockHeight
    )
        public
        Core(
            _chainId,
            _epochLength,
            _minValidators,
            _joinLimit,
            _reputation,
            _height,
            _parent,
            _gasTarget,
            _dynasty,
            _accumulatedGas,
            _source,
            _sourceBlockHeight
        )
    {
    }


    /* External Functions */

    function externalHashKernel(
        uint256 _height,
        bytes32 _parent,
        address[] calldata _updatedValidators,
        uint256[] calldata _updatedReputation,
        uint256 _gasTarget
    )
        external
        view
        returns (bytes32 hash_)
    {
        hash_ = super.hashKernel(
            _height,
            _parent,
            _updatedValidators,
            _updatedReputation,
            _gasTarget
        );
    }

    function updatedValidatorsCount(uint256 _height)
        external
        view
        returns (uint256)
    {
        return kernels[_height].updatedValidators.length;
    }

    function updatedValidator(uint256 _height, uint256 _index)
        external
        view
        returns (address)
    {
        return kernels[_height].updatedValidators[_index];
    }

    function updatedReputationCount(uint256 _height)
        external
        view
        returns (uint256)
    {
        return kernels[_height].updatedReputation.length;
    }

    function updatedReputation(uint256 _height, uint256 _index)
        external
        view
        returns (uint256)
    {
        return kernels[_height].updatedReputation[_index];
    }
}

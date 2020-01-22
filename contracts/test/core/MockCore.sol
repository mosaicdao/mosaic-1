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

import "../../core/Core.sol";

contract MockCore is Core {

    /* External Functions */

    function updateJoinLimit(uint256 _joinLimit)
        external
    {
        require(
            _joinLimit != uint256(0),
            "Validator's join limit is 0."
        );

        joinLimit = _joinLimit;
    }

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

    function updatedValidators(uint256 _height)
        external
        view
        returns (address[] memory)
    {
        return kernels[_height].updatedValidators;
    }

    function updatedReputations(uint256 _height)
        external
        view
        returns (uint256[] memory)
    {
        return kernels[_height].updatedReputation;
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

    function isProposalSetInitialized(uint256 _kernelHeight)
        external
        view
        returns (bool)
    {
        return proposals[_kernelHeight][SENTINEL_PROPOSALS] != bytes32(0);
    }

    function addValidator(
        address _validator,
        uint256 beginHeight,
        uint256 endHeight
    )
        public
    {
        validatorBeginHeight[_validator] = beginHeight;
        validatorEndHeight[_validator] = endHeight;
    }

    function setOpenkernelHeight(uint256 _openKernelHeight) public {
        openKernelHeight = _openKernelHeight;
    }

    function setOpenKernelHash(bytes32 _openKernelHash) public {
        openKernelHash = _openKernelHash;
    }

}

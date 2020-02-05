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

import "../../message-bus/Proof.sol";
import "../../message-bus/StateRootI.sol";
import "../../lib/CircularBufferUint.sol";

contract ProofDouble is Proof {

    function setupProofDouble(
        address _storageAccount,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        external
    {
        Proof.setupProof(
            _storageAccount,
            _stateRootProvider,
            _maxStorageRootItems
        );
    }


    function proveStorageAccountDouble(
        uint256 _blockHeight,
        bytes calldata _rlpAccount,
        bytes calldata _rlpParentNodes
    )
        external
    {
        Proof.proveStorageAccount(
            _blockHeight,
            _rlpAccount,
            _rlpParentNodes
        );
    }

    function proveStorageExistenceDouble(
        bytes calldata _path,
        bytes32 _value,
        uint256 _blockHeight,
        bytes calldata _rlpParentNodes
    )
        external
        view
    {
        Proof.proveStorageExistence(
            _path,
            _value,
            _blockHeight,
            _rlpParentNodes
        );
    }

    function storagePathDouble(
        uint8 _index,
        bytes32 _key
    )
        external
        pure
        returns(bytes memory storagePath_)
    {
        storagePath_ = Proof.storagePath(
            _index,
            _key
        );
    }

    function setStorageRootDouble(
        uint256 _blockHeight,
        bytes32 _storageRoot
    )
        external
    {
        Proof.storageRoots[_blockHeight] = _storageRoot;
    }
}

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

import "../../message-bus/Proof.sol";

/**
 * @title ProofDouble - Contract to test Proof contract.
 */
contract ProofDouble is Proof {

    /* External Functions */

    /**
     * @notice It is used to test Proof::setupProof
     */
    function setupProofExternal(
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

    /**
     * @notice It is used to test Proof::proveStorageAccount
     */
    function proveStorageAccountExternal(
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

    /**
     * @notice It is used to test Proof::proveStorageExistence
     */
    function proveStorageExistenceExternal(
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

    /**
     * @notice It is used to test Proof::storagePath
     */
    function storagePathExternal(
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

    /**
     * @notice It is used to set the storage root for _blockHeight
     *
     * @param _blockHeight Block height for which the storage root will be set
     * @param _storageRoot Storage root
     */
    function setStorageRootExternal(
        uint256 _blockHeight,
        bytes32 _storageRoot
    )
        external
    {
        Proof.storageRoots[_blockHeight] = _storageRoot;
    }
}

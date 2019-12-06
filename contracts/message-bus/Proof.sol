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

import "../lib/CircularBufferUint2.sol";
import "./StateRootI.sol";
import "../lib/RLP.sol";
import "../lib/MerklePatriciaProof.sol";
import "../lib/BytesLib.sol";

// TODO: Once  CircularBufferUint contract is updated in other issue/PR rename
// `CircularBufferUint2` to `CircularBufferUint`
contract Proof is CircularBufferUint2{

    /* Variables */

    /** Contract address for which the storage is to be proved. */
    address public storageAccount;

    /** State root provider address. */
    StateRootI public stateRootProvider;

    /** Encoded account path. */
    bytes public encodedAccountPath;

    /** Maps blockHeight to storageRoot. */
    mapping(uint256 => bytes32) public storageRoots;


    /* Internal Functions */

    /**
     * @notice Setup the proof contract. This can be called only once.
     * @param _storageAccount Storage account that will be proved.
     * @param _stateRootProvider State root provider contract address.
     * @param _maxStorageRootItems Defines how many storage roots should be
     *                             stored in circular buffer.
     */
    function initialize(
        address _storageAccount,
        StateRootI _stateRootProvider,
        uint256 _maxStorageRootItems
    )
        internal
    {
        // Check if this is called only once.
        require(
            address(_stateRootProvider) == address(0),
            "Setup is already done."
        );

        require(
            _storageAccount != address(0),
            "Storage account address is 0."
        );

        require(
            address(_stateRootProvider) != address(0),
            "State root provider address is 0."
        );

        CircularBufferUint2.setupCircularBuffer(_maxStorageRootItems);

        storageAccount = _storageAccount;
        stateRootProvider = _stateRootProvider;

        encodedAccountPath = BytesLib.bytes32ToBytes(
            keccak256(abi.encodePacked(_storageAccount))
        );
    }

    /**
     *  @notice Verify merkle proof of a storage contract address.
     *          Trust factor is brought by state roots of the contract which
     *          implements StateRootInterface.
     *  @param _blockHeight Block height at which Gateway/CoGateway is to be
     *                      proven.
     *  @param _rlpAccount RLP encoded account node object.
     *  @param _rlpParentNodes RLP encoded value of account proof parent nodes.
     *  @return `true` if Gateway account is proved
     */
    function proveStorageAccount(
        uint256 _blockHeight,
        bytes memory _rlpAccount,
        bytes memory _rlpParentNodes
    )
        internal
    {
        // _rlpAccount should be valid
        require(
            _rlpAccount.length != 0,
            "Length of RLP account must not be 0."
        );

        // _rlpParentNodes should be valid
        require(
            _rlpParentNodes.length != 0,
            "Length of RLP parent nodes is 0"
        );

        bytes32 stateRoot = stateRootProvider.getStateRoot(_blockHeight);

        // State root should be present for the block height
        require(
            stateRoot != bytes32(0),
            "State root must not be zero"
        );

        // If account already proven for block height
        bytes32 provenStorageRoot = storageRoots[_blockHeight];

        if (provenStorageRoot == bytes32(0)) {
            bytes32 storageRoot = proveAccount(
                _rlpAccount,
                _rlpParentNodes,
                encodedAccountPath,
                stateRoot
            );

            storageRoots[_blockHeight] = storageRoot;
            uint256 oldestStoredBlockHeight = CircularBufferUint2.store(_blockHeight);
            delete storageRoots[oldestStoredBlockHeight];
        }
    }

    /**
     * @notice Prove the existence of data in the storage contract by providing
     *         the Merkle proof.
     * @param _path Storage path
     * @param _value Storage value.
     * @param _blockHeight Storage root block height.
     * @param _rlpParentNodes RLP encoded value of account proof parent nodes.
     */
    function proveStorageExistence(
        bytes memory _path,
        bytes32 _value,
        uint256 _blockHeight,
        bytes memory _rlpParentNodes
    )
        internal
        view
    {
        // Get storage root.
        bytes32 storageRoot = storageRoots[_blockHeight];
        require(
            storageRoot != bytes32(0),
            "Storage root must not be zero"
        );

        // Verify the merkle proof.
        require(
            MerklePatriciaProof.verify(
                _value,
                _path,
                _rlpParentNodes,
                storageRoot
            ),
            "Merkle proof verification failed."
        );
    }

    /**
     * @notice Get the storage path of the variable inside the struct.
     *
     * @param _index Index of the variable
     * @param _key Key of variable in case of mapping
     *
     * @return storagePath_ Storage path of the variable.
     */
    function storagePath(
        uint8 _index,
        bytes32 _key
    )
        internal
        pure
        returns(bytes memory storagePath_)
    {
        bytes memory indexBytes = BytesLib.leftPad(
            BytesLib.bytes32ToBytes(bytes32(uint256(_index)))
        );

        bytes memory keyBytes = BytesLib.leftPad(BytesLib.bytes32ToBytes(_key));
        bytes memory path = BytesLib.concat(keyBytes, indexBytes);

        storagePath_ = BytesLib.bytes32ToBytes(
            keccak256(
                abi.encodePacked(keccak256(abi.encodePacked(path)))
            )
        );
    }


    /* Private Functions */

    /**
     * @notice Merkle proof verification of account.
     * @param _rlpAccount RLP encoded data of account.
     * @param _rlpParentNodes Path from root node to leaf in merkle tree.
     * @param _encodedPath Encoded path to search account node in merkle tree.
     * @param _stateRoot State root for given block height.
     * @return bytes32 Storage path of the variable.
     */
    function proveAccount(
        bytes memory _rlpAccount,
        bytes memory _rlpParentNodes,
        bytes memory _encodedPath,
        bytes32 _stateRoot
    )
        private
        pure
        returns (bytes32 storageRoot_)
    {
        // Decode RLP encoded account value.
        RLP.RLPItem memory accountItem = RLP.toRLPItem(_rlpAccount);

        // Convert to list.
        RLP.RLPItem[] memory accountArray = RLP.toList(accountItem);

        // Array 3rd position is storage root.
        storageRoot_ = RLP.toBytes32(accountArray[2]);

        // Hash the rlpValue value.
        bytes32 hashedAccount = keccak256(
            abi.encodePacked(_rlpAccount)
        );

        /*
         * Verify the remote OpenST contract against the committed state
         * root with the state trie Merkle proof.
         */
        require(
            MerklePatriciaProof.verify(
                hashedAccount,
                _encodedPath,
                _rlpParentNodes,
                _stateRoot
            ),
            "Account proof is not verified."
        );
    }
}

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

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./AnchorI.sol";

import "../consensus/ConsensusModule.sol";
import "../lib/CircularBufferUint.sol";
import "../lib/MerklePatriciaProof.sol";
import "../lib/RLP.sol";

/**
 * @title Anchor contract which implements StateRootInterface.
 *
 * @notice Anchor stores another chain's state roots. It stores the address of
 *         the co-anchor, which will be the anchor on the other chain. State
 *         roots are exchanged bidirectionally between the anchor and the
 *         co-anchor by the consensus.
 */
contract Anchor is AnchorI, ConsensusModule, CircularBufferUint {

    /* Usings */

    using SafeMath for uint256;


    /* Events */

    event StateRootAvailable(uint256 _blockHeight, bytes32 _stateRoot);


    /* Storage */

    /** Maps block heights to their respective state root. */
    mapping (uint256 => bytes32) private stateRoots;


    /*  Constructor */

    /**
     * @notice Contract constructor.
     *
     * @param _blockHeight Block height at which _stateRoot needs to store.
     * @param _stateRoot State root hash of given _blockHeight.
     * @param _maxStateRoots The max number of state roots to store in the
     *                       circular buffer.
     * @param _consensus A consensus address.
     */
    constructor(
        uint256 _blockHeight,
        bytes32 _stateRoot,
        uint256 _maxStateRoots,
        ConsensusI _consensus
    )
        CircularBufferUint(_maxStateRoots)
        public
    {
        setup(_consensus);
        stateRoots[_blockHeight] = _stateRoot;
        CircularBufferUint.store(_blockHeight);
    }


    /* External functions */

    /**
     * @notice Get the state root for the given block height.
     *
     * @param _blockHeight The block height for which the state root is needed.
     *
     * @return bytes32 State root of the given height.
     */
    function getStateRoot(
        uint256 _blockHeight
    )
        external
        view
        returns (bytes32 stateRoot_)
    {
        stateRoot_ = stateRoots[_blockHeight];
    }

    /**
     * @notice Gets the block height of latest anchored state root.
     *
     * @return uint256 Block height of the latest anchored state root.
     */
    function getLatestStateRootBlockHeight()
        external
        view
        returns (uint256 height_)
    {
        height_ = CircularBufferUint.head();
    }

    /**
     *  @notice External function anchorStateRoot.
     *
     *  @dev anchorStateRoot Called from game process.
     *       Anchor new state root for a block height.
     *
     *  @param _blockHeight Block height for which stateRoots mapping needs to
     *                      update.
     *  @param _stateRoot State root of input block height.
     */
    function anchorStateRoot(
        uint256 _blockHeight,
        bytes32 _stateRoot
    )
        external
        onlyConsensus
    {
        // State root should be valid
        require(
            _stateRoot != bytes32(0),
            "State root must not be zero."
        );

        // Input block height should be valid.
        require(
            _blockHeight > CircularBufferUint.head(),
            "Given block height is lower or equal to highest anchored state root block height."
        );

        stateRoots[_blockHeight] = _stateRoot;
        uint256 oldestStoredBlockHeight = CircularBufferUint.store(_blockHeight);
        delete stateRoots[oldestStoredBlockHeight];

        emit StateRootAvailable(_blockHeight, _stateRoot);
    }
}

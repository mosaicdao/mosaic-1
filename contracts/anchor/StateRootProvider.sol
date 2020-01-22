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

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../lib/CircularBufferUint.sol";

contract StateRootProvider is CircularBufferUint {

    /* Usings */

    using SafeMath for uint256;


    /* Events */

    event StateRootAvailable(uint256 _blockHeight, bytes32 _stateRoot);


    /* Storage */

    /** Maps block heights to their respective state root. */
    mapping (uint256 => bytes32) private stateRoots;


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


    /* Internal functions */

    /**
     * @notice Setup function for state root provider contract.
     *
     * @param _maxStateRoots The max number of state roots to store in the
     *                       circular buffer.
     */
    function setup(
        uint256 _maxStateRoots
    )
        internal
    {
        setupCircularBuffer(_maxStateRoots);
    }

    /**
     * @notice Anchor the state root for an (increasing) block height.
     *
     * @dev  Function requires:
     *          - stateRoot must not be zero
     *          - blockHeight value must be greater than latestStateRootBlockHeight
     *
     * @param _blockHeight Block height for which state root needs to
     *                      update.
     * @param _stateRoot State root of input block height.
     */
    function anchorStateRoot(
        uint256 _blockHeight,
        bytes32 _stateRoot
    )
        internal
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
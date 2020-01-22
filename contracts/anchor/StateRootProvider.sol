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

    event StateRootAvailable(uint256 _blockNumber, bytes32 _stateRoot);


    /* Storage */

    /** Maps block numbers to their respective state root. */
    mapping (uint256 => bytes32) private stateRoots;


    /* External functions */

    /**
     * @notice Get the state root for the given block number.
     *
     * @param _blockNumber The block number for which the state root is needed.
     *
     * @return bytes32 State root of the given number.
     */
    function getStateRoot(
        uint256 _blockNumber
    )
        external
        view
        returns (bytes32 stateRoot_)
    {
        stateRoot_ = stateRoots[_blockNumber];
    }

    /**
     * @notice Gets the block number of latest anchored state root.
     *
     * @return uint256 Block number of the latest anchored state root.
     */
    function getLatestStateRootBlockNumber()
        external
        view
        returns (uint256 blockNumber_)
    {
        blockNumber_ = CircularBufferUint.head();
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
     * @notice Anchor the state root for an (increasing) block number.
     *
     * @dev  Function requires:
     *          - stateRoot must not be zero
     *          - blockNumber value must be greater than latestStateRootBlockNumber
     *
     * @param _blockNumber Block number for which state root needs to
     *                      update.
     * @param _stateRoot State root of input block number.
     */
    function anchorStateRootInternal(
        uint256 _blockNumber,
        bytes32 _stateRoot
    )
        internal
    {
        // State root should be valid
        require(
            _stateRoot != bytes32(0),
            "State root must not be zero."
        );

        // Input block number should be valid.
        require(
            _blockNumber > CircularBufferUint.head(),
            "Given block number is lower or equal to highest anchored state root block number."
        );

        stateRoots[_blockNumber] = _stateRoot;
        uint256 oldestStoredBlockNumber = CircularBufferUint.store(_blockNumber);
        delete stateRoots[oldestStoredBlockNumber];

        emit StateRootAvailable(_blockNumber, _stateRoot);
    }
}

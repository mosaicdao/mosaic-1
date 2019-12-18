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

import "../ERC20I.sol";

/** Base contract for ConsensusGateway and ConsensusCogateway contracts. */
contract ConsensusGatewayBase {

    /* Constants */

    bytes32 public constant KERNEL_INTENT_TYPEHASH = keccak256(
        abi.encode(
            "KernelIntent(uint256 height,bytes32 kernelHash)"
        )
    );

    bytes32 public constant DEPOSIT_INTENT_TYPEHASH = keccak256(
        abi.encode(
            "DepositIntent(uint256 amount,address beneficiary)"
        )
    );


    /* Storage */

    /** Address of most contract on origin or auxiliary chain. */
    ERC20I public most;

    /** Mapping of message sender and nonce. */
    mapping(address => uint256) public  nonces;

    /** Height of current metablock */
    uint256 public currentMetablockHeight;


    /* Public function */

    /**
     * @notice Creates kernel intent hash.
     *
     * @param _height Height of meta-block.
     * @param _kernelHash Hash of kernel at given height.
     *
     * @return kernelIntentHash_ Kernel intent hash.
     */
    function hashKernelIntent(
        uint256 _height,
        bytes32 _kernelHash
    )
        public
        pure
        returns(bytes32 kernelIntentHash_)
    {
        kernelIntentHash_ = keccak256(
            abi.encode(
                KERNEL_INTENT_TYPEHASH,
                _height,
                _kernelHash
            )
        );
    }

    /**
     * @notice Creates deposit intent hash.
     *
     * @param _amount Amount of most token in wei.
     * @param _beneficiary Address of beneficiary.
     *
     * @return depositIntentHash_ Deposit intent hash.
     */
    function hashDepositIntent(
        uint256 _amount,
        address _beneficiary
    )
        public
        pure
        returns(bytes32 depositIntentHash_)
    {
        depositIntentHash_ = keccak256(
            abi.encode(
                DEPOSIT_INTENT_TYPEHASH,
                _amount,
                _beneficiary
            )
        );
    }


    /* Internal functions. */

    function setup(
        ERC20I _most,
        uint256 _currentMetablockHeight
    )
        internal
    {
        require(
            address(_most) != address(0),
            "most address must not be 0."
        );

        currentMetablockHeight = _currentMetablockHeight;
        most = _most;
    }
}

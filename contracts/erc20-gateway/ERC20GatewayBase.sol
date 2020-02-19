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

contract ERC20GatewayBase {

    /* Usings */

    using SafeMath for uint256;


    /* Events */

    /** Emitted when Gateway/Cogateway contract is proven. */
    event GatewayProven(address gateway, uint256 blockNumber);


    /* Constants */

    bytes32 constant public DEPOSIT_INTENT_TYPEHASH = keccak256(
        "DepositIntent(uint256 amount,address beneficiary)"
    );

    bytes32 constant public WITHDRAW_INTENT_TYPEHASH = keccak256(
        "WithdrawIntent(uint256 amount,address beneficiary)"
    );


    /* Public functions */

    /**
     * @notice It returns hash of deposit intent.
     *
     * @param _amount Amount of tokens.
     * @param _beneficiary Beneficiary address.
     *
     * @return depositIntentHash_ Hash of deposit intent.
     */
    function hashDepositIntent(
        uint256 _amount,
        address _beneficiary
    )
        public
        pure
        returns (bytes32 depositIntentHash_)
    {
        depositIntentHash_ = keccak256(
            abi.encode(
                DEPOSIT_INTENT_TYPEHASH,
                _amount,
                _beneficiary
            )
        );
    }


    /**
     * @notice It returns hash of withdraw intent.
     *
     * @param _amount Amount of tokens.
     * @param _beneficiary Beneficiary address.
     *
     * @return withdrawIntentHash_ Hash of withdraw intent.
     */
    function hashWithdrawIntent(
        uint256 _amount,
        address _beneficiary
    )
        public
        pure
        returns (bytes32 withdrawIntentHash_)
    {
        withdrawIntentHash_ = keccak256(
            abi.encode(
                WITHDRAW_INTENT_TYPEHASH,
                _amount,
                _beneficiary
            )
        );
    }


    /* Internal functions */

    /**
     * @notice Calculates reward.
     *
     * @param _gasConsumed Gas consumption in a transaction.
     * @param _feeGasPrice Gas price at which fee will be calculated.
     * @param _feeGasLimit Gas limit at which fee will be capped.
     *
     * @return rewardAmount_ Total reward amount.
     */
    function reward(
        uint256 _gasConsumed,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit
    )
        internal
        pure
        returns(uint256 rewardAmount_)
    {
        if(_gasConsumed > _feeGasLimit) {
            rewardAmount_ = _feeGasPrice.mul(_feeGasLimit);
        } else {
            rewardAmount_ = _feeGasPrice.mul(_gasConsumed);
        }
    }
}

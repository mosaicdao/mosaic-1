pragma solidity >=0.5.0 <0.6.0;

contract ERC20GatewayBase {

    /* Storage */

    bytes32 constant public DEPOSIT_INTENT_TYPEHASH = keccak256(
        "DepositIntent(uint256 amount,address beneficiary)"
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
}

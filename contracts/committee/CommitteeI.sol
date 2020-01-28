pragma solidity >=0.5.0 <0.6.0;

interface CommitteeI {

    /**
     * @notice Enters a `_validator` into the committee.
     * @param _validator Validator address to enter.
     *                   The specified address:
     *                      - is not 0
     *                      - is not the member-sentinel
     *                      - has not been already entered
     * @param _furtherMember Further member (compared with the validator)
     *                       address. The specified address:
     *                          - has been already entered
     */
    function enterCommittee(
        address _validator,
        address _furtherMember
    )
        external;

    /**
     * Committee decision once the quorum is reached.
     */
    function committeeDecision() external view returns (bytes32);

    /**
     * For accessing quorum.
     */
    function quorum() external view returns (uint256);
}

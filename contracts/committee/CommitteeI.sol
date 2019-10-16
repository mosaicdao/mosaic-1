pragma solidity ^0.5.0;

interface CommitteeI {

    function enterCommittee(
        address _validator,
        address _furtherMember
    )
        external
        returns (bool);

    function committeeDecision() external view returns (bytes32);
}

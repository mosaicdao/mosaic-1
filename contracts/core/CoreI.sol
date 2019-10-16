pragma solidity ^0.5.0;

interface CoreI {

    function assertPrecommit(
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        external
        view
        returns (bytes32 proposal_);

    function joinDuringCreation(address _validator) external;

    function join(address _validator) external;

    function logout(address _validator) external;
}

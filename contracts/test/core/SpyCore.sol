pragma solidity ^0.5.0;

import "../../core/CoreI.sol";
import "../../proxies/MasterCopyNonUpgradable.sol";

contract SpyCore is MasterCopyNonUpgradable, CoreI{

    uint256 public minimumValidatorCount = 3;

    bytes32 public mockedOpenKernelHash;
    bytes32 public mockedPrecommit;

    address public spyConsensus;
    bytes20 public spyChainId;
    uint256 public spyEpochLength;
    uint256 public spyMinValidators;
    uint256 public spyJoinLimit;
    address public spyReputation;
    uint256 public spyHeight;
    bytes32 public spyParent;
    uint256 public spyGasTarget;
    uint256 public spyDynasty;
    uint256 public spyAccumulatedGas;
    bytes32 public spySource;
    uint256 public spySourceBlockHeight;

    address public spyValidator;

    bytes32 public spyCommittedOriginObservation;
    uint256 public spyCommittedDynasty;
    uint256 public spyCommittedAccumulatedGas;
    bytes32 public spyCommittedCommitteeLock;
    bytes32 public spyCommittedSource;
    bytes32 public spyCommittedTarget;
    uint256 public spyCommittedSourceBlockHeight;
    uint256 public spyCommittedTargetBlockHeight;
    uint256 public spyDeltaGasTarget;

    function setup(
        address _consensus,
        bytes20 _chainId,
        uint256 _epochLength,
        uint256 _minValidators,
        uint256 _joinLimit,
        address _reputation,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _source,
        uint256 _sourceBlockHeight
    )
        external
    {

        spyConsensus = _consensus;
        spyChainId = _chainId;
        spyEpochLength = _epochLength;
        spyMinValidators = _minValidators;
        spyJoinLimit = _joinLimit;
        spyReputation = address(_reputation);
        spyHeight = _height;
        spyParent = _parent;
        spyGasTarget = _gasTarget;
        spyDynasty = _dynasty;
        spyAccumulatedGas = _accumulatedGas;
        spySource = _source;
        spySourceBlockHeight = _sourceBlockHeight;
    }
    function joinDuringCreation(address _validator)
        external
        returns (uint256)
    {
        spyValidator = _validator;
    }

    function join(address _validator) external {
        spyValidator = _validator;
    }

    function logout(address _validator) external {
        spyValidator = _validator;
    }

    function openMetablock(
        bytes32 _committedOriginObservation,
        uint256 _committedDynasty,
        uint256 _committedAccumulatedGas,
        bytes32 _committedCommitteeLock,
        bytes32 _committedSource,
        bytes32 _committedTarget,
        uint256 _committedSourceBlockHeight,
        uint256 _committedTargetBlockHeight,
        uint256 _deltaGasTarget
    )
        external
    {
        spyCommittedOriginObservation = _committedOriginObservation;
        spyCommittedDynasty = _committedDynasty;
        spyCommittedAccumulatedGas = _committedAccumulatedGas;
        spyCommittedCommitteeLock = _committedCommitteeLock;
        spyCommittedSource = _committedSource;
        spyCommittedTarget = _committedTarget;
        spyCommittedSourceBlockHeight = _committedSourceBlockHeight;
        spyCommittedTargetBlockHeight = _committedTargetBlockHeight;
        spyDeltaGasTarget = _deltaGasTarget;
    }

    function assertPrecommit(
        bytes32,
        bytes32,
        uint256,
        uint256,
        bytes32,
        bytes32,
        bytes32,
        uint256,
        uint256
    )
        external
        view
        returns (bytes32)
    {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
    }

    function mockPrecommit(bytes32 _precommitHash) external {
        mockedPrecommit = _precommitHash;
    }
    function precommit() external returns (bytes32) {
        return mockedPrecommit;
    }

    function mockOpenKernelHash(bytes32 _kernelHash) external {
        mockedOpenKernelHash = _kernelHash;
    }

    function openKernelHash() external returns (bytes32) {
        return mockedOpenKernelHash;
    }
}

pragma solidity >=0.5.0 <0.6.0;

import "../../core/CoreI.sol";
import "../../proxies/MasterCopyNonUpgradable.sol";

contract SpyCore is MasterCopyNonUpgradable, CoreI{

    uint256 public minimumValidatorCount = 3;

    bytes32 public mockedOpenKernelHash;
    bytes32 public mockedPrecommit;

    address public spyConsensus;
    bytes32 public spyMetachainId;
    uint256 public spyEpochLength;
    uint256 public spyMinValidators;
    uint256 public spyJoinLimit;
    address public spyReputation;
    uint256 public spyHeight;
    bytes32 public spyParent;
    uint256 public spyGasTarget;
    uint256 public spyDynasty;
    uint256 public spyAccumulatedGas;
    uint256 public spySourceBlockHeight;

    address public spyValidator;

    uint256 public spyCommittedDynasty;
    uint256 public spyCommittedAccumulatedGas;
    bytes32 public spyCommittedSource;
    uint256 public spyCommittedSourceBlockHeight;
    uint256 public spyDeltaGasTarget;

    function setup(
        address _consensus,
        bytes32 _metachainId,
        uint256 _epochLength,
        uint256 _minValidators,
        uint256 _joinLimit,
        address _reputation,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        uint256 _sourceBlockHeight
    )
        external
    {

        spyConsensus = _consensus;
        spyMetachainId = _metachainId;
        spyEpochLength = _epochLength;
        spyMinValidators = _minValidators;
        spyJoinLimit = _joinLimit;
        spyReputation = address(_reputation);
        spyHeight = _height;
        spyParent = _parent;
        spyGasTarget = _gasTarget;
        spyDynasty = _dynasty;
        spyAccumulatedGas = _accumulatedGas;
        spySourceBlockHeight = _sourceBlockHeight;
    }
    function joinBeforeOpen(address _validator)
        external
        returns (uint256, uint256)
    {
        spyValidator = _validator;
    }

    function join(address _validator) external {
        spyValidator = _validator;
    }

    function logout(address _validator) external returns (uint256) {
        spyValidator = _validator;
    }

    function openMetablock(
        uint256 _committedDynasty,
        uint256 _committedAccumulatedGas,
        uint256 _committedSourceBlockHeight,
        uint256 _deltaGasTarget
    )
        external
    {
        spyCommittedDynasty = _committedDynasty;
        spyCommittedAccumulatedGas = _committedAccumulatedGas;
        spyCommittedSourceBlockHeight = _committedSourceBlockHeight;
        spyDeltaGasTarget = _deltaGasTarget;
    }

    function hashMetablock(
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

    // Note: Implementation will be done once it is required. As the method is
    // in ICore interface, we would need it, otherwise SpyCore deployment cannot
    // be done.
    function isValidator(address)
        external
        view
        returns (bool)
    {
        require(false, "This should not be called for unit tests.");
    }

    function getOpenKernel()
        external
        returns (bytes32 openKernelHash_, uint256 openKernelHeight_)
    {
        openKernelHash_ = bytes32(0);
        openKernelHeight_ = 1;
    }
}

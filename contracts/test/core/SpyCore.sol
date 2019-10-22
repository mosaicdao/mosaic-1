pragma solidity ^0.5.0;

import "../../core/CoreI.sol";
import "../../proxies/MasterCopyNonUpgradable.sol";

contract SpyCore is MasterCopyNonUpgradable, CoreI{

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
    function joinDuringCreation(address) external {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
    }

    function join(address) external {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
    }

    function logout(address) external {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
    }

    function openMetablock(
        bytes32,
        uint256,
        uint256,
        bytes32,
        bytes32,
        bytes32,
        uint256,
        uint256,
        uint256
    )
        external
    {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
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
}

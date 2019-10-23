pragma solidity ^0.5.0;

import "../../proxies/MasterCopyNonUpgradable.sol";
import "../../consensus/ConsensusI.sol";
import "../../axiom/AxiomI.sol";

contract SpyConsensus is MasterCopyNonUpgradable, ConsensusI {

    uint256 public committeeSize;
    uint256 public minValidators;
    uint256 public joinLimit;
    uint256 public gasTargetDelta;
    uint256 public coinbaseSplitPerMille;
    address public reputation;

    bytes20 public chainId;
    uint256 public epochLength;
    bytes32 public source;
    uint256 public sourceBlockHeight;

    address public deployedContractAddress;

    function setup(
        uint256 _committeeSize,
        uint256 _minValidators,
        uint256 _joinLimit,
        uint256 _gasTargetDelta,
        uint256 _coinbaseSplitPerMille,
        address _reputation
    )
        external
    {
        committeeSize =_committeeSize;
        minValidators =_minValidators;
        joinLimit = _joinLimit;
        gasTargetDelta = _gasTargetDelta;
        coinbaseSplitPerMille = _coinbaseSplitPerMille;
        reputation = _reputation;
    }

    function getReservedStorageSlotForProxy() external view returns (address) {
        return reservedStorageSlotForProxy;
    }

    function newMetaChain(
        bytes20 _chainId,
        uint256 _epochLength,
        bytes32 _source,
        uint256 _sourceBlockHeight
    )
        external
    {
        chainId = _chainId;
        epochLength = _epochLength;
        source = _source;
        sourceBlockHeight = _sourceBlockHeight;
    }

    function callNewCore(
        AxiomI _axiom,
        bytes calldata _data
    )
        external
    {
        deployedContractAddress = _axiom.newCore(_data);
    }

    function callNewCommittee(
        AxiomI _axiom,
        bytes calldata _data
    )
    external
    {
        deployedContractAddress = _axiom.newCommittee(_data);
    }

    function coreValidatorThresholds()
        external
        view
        returns (
            uint256,
            uint256
    ) {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
    }

    function registerPrecommit(bytes32) external {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
    }
}

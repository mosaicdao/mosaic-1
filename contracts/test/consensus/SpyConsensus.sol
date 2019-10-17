pragma solidity ^0.5.0;

import "../../proxies/MasterCopyNonUpgradable.sol";

contract SpyConsensus is MasterCopyNonUpgradable {

    uint256 public committeeSize;
    uint256 public minValidators;
    uint256 public joinLimit;
    uint256 public gasTargetDelta;
    uint256 public coinbaseSplitPercentage;
    address public reputation;

    function setup(
        uint256 _committeeSize,
        uint256 _minValidators,
        uint256 _joinLimit,
        uint256 _gasTargetDelta,
        uint256 _coinbaseSplitPercentage,
        address _reputation
    )
        external
    {
        committeeSize =_committeeSize;
        minValidators =_minValidators;
        joinLimit = _joinLimit;
        gasTargetDelta = _gasTargetDelta;
        coinbaseSplitPercentage = _coinbaseSplitPercentage;
        reputation = _reputation;
    }

    function getReservedStorageSlotForProxy() external view returns (address) {
        return reservedStorageSlotForProxy;
    }
}

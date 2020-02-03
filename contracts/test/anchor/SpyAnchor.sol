pragma solidity >=0.5.0 <0.6.0;

import "../../anchor/AnchorI.sol";
import "../../consensus/ConsensusI.sol";
import "../../proxies/MasterCopyNonUpgradable.sol";

contract SpyAnchor is MasterCopyNonUpgradable, AnchorI{

    uint256 public spyBlockHeight;
    bytes32 public spyStateRoot;
    uint256 public spyMaxStateRoot;
    address public spyConsensus;


    function setup(
        uint256 _maxStateRoots,
        ConsensusI _consensus
    )
        external
    {
        spyMaxStateRoot = _maxStateRoots;
        spyConsensus = address(_consensus);
    }

    function getLatestStateRootBlockHeight()
        external
        view
        returns (uint256)
    {
        require(false, 'SpyAnchor::getLatestStateRootBlockHeight should not be called.');
    }

    function getStateRoot(uint256 _blockHeight)
        external
        returns (bytes32)
    {
        // require(false, 'SpyAnchor::getStateRoot should not be called.');
        spyBlockHeight = _blockHeight;
        return spyStateRoot;
    }

    function anchorStateRoot(
        uint256 _blockHeight,
        bytes32 _stateRoot
    )
        external
    {
        spyBlockHeight = _blockHeight;
        spyStateRoot = _stateRoot;
    }
}

pragma solidity ^0.5.0;

import "../../anchor/AnchorI.sol";

contract SpyAnchor is AnchorI{

    uint256 public spyBlockHeight;
    bytes32 public spyStateRoot;

    function getLatestStateRootBlockHeight()
        external
        view
        returns (uint256)
    {
        require(false, 'SpyAnchor::getLatestStateRootBlockHeight should not be called.');
    }

    function getStateRoot(uint256)
        external
        view
        returns (bytes32)
    {
        require(false, 'SpyAnchor::getStateRoot should not be called.');
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

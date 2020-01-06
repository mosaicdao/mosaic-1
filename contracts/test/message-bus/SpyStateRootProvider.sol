pragma solidity >=0.5.0 <0.6.0;


contract SpyStateRootProvider {

    mapping(uint256 => bytes32) stateRoots;

    function getStateRoot(uint256 _blockHeight) public returns(bytes32){
            return stateRoots[_blockHeight];
    }

    function setStateRoot(bytes32 _stateRoot, uint256 _blockHeight) public returns(bytes32){
        stateRoots[_blockHeight] = _stateRoot;
    }
}

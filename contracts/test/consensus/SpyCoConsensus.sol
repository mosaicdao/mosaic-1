pragma solidity >=0.5.0 <0.6.0;

contract SpyCoConsensus {

    mapping(bytes32 => address) public anchors;

    bool public called;

    function setAnchorAddress(bytes32 _metachainId, address anchor) public {
        anchors[_metachainId] = anchor;
    }

    function getAnchor(bytes32 _metachainId) public returns(address) {
        called = true;
        return anchors[_metachainId];
    }

}

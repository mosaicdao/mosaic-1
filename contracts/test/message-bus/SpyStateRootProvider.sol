pragma solidity >=0.5.0 <0.6.0;

/**
 * @title SpyStateRootProvider
 *
 * @notice It is Spy for StateRootProvider contract.
 */
contract SpyStateRootProvider {

    /* Storage */

    mapping(uint256 => bytes32) stateRoots;


    /* Public functions */

    /**
     * @notice It returns stateroot for a blockheight.
     *
     * @param _blockHeight Blockheight for which stateroot is required.
     *
     * @return Stateroot for the blockheight.
     */
    function getStateRoot(uint256 _blockHeight) public view returns(bytes32) {
        return stateRoots[_blockHeight];
    }

    /**
     * @notice It sets stateroot for a blockheight
     *
     * @param _stateRoot State root for a blocknumber.
     * @param _blockHeight Block height.
     */
    function setStateRoot(bytes32 _stateRoot, uint256 _blockHeight) public {
        stateRoots[_blockHeight] = _stateRoot;
    }
}

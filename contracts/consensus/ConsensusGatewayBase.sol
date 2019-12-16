pragma solidity >=0.5.0 <0.6.0;

import "./ConsensusModule.sol";
import "../ERC20I.sol";


contract ConsensusGatewayBase is ConsensusModule {

    /* Storage */

    /** Address of MOst contract address. */
    ERC20I public  most;


    /* Internal methods */

    /**
     * @notice It sets consensus and most contract addresses.
     *
     * @param _consensus Address of consensus contract.
     * @param _most Address of most contract.
     */
    function setupConsensusGatewayBase(
        address _consensus,
        ERC20I _most
    )
        internal
    {
        require(
            address(_most) != address(0),
            "MOst address is 0"
        );
        ConsensusModule.setupConsensus(ConsensusI(_consensus));

        most = _most;
    }
}

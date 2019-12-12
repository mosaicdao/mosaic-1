pragma solidity >=0.5.0 <0.6.0;

interface AxiomI {

    /**
     * @notice Deploy Core proxy contract. This can be called only by consensus
     *         contract.
     * @param _data Setup function call data.
     * @return Deployed contract address.
     */
    function newCore(
        bytes calldata _data
    )
        external
        returns (address);

    /**
     * @notice Deploy Committee proxy contract. This can be called only by consensus
     *         contract.
     * @param _data Setup function call data.
     * @return Deployed contract address.
     */
    function newCommittee(
        bytes calldata _data
    )
        external
        returns (address);

    /**
     * @notice Deploys metachain proxies. Only consensus can call this function.
     *
     * @param _coreSetupData Setup data for core contract.
     * @param _consensusGatewaySetupData Setup data for consensus gateway contract.
     *
     * @return core_ Address of core contract.
     * @return consensusGateway_ Address of consensus gateway contract.
     */
    function deployMetachainProxies(
        bytes calldata _coreSetupData,
        bytes calldata _consensusGatewaySetupData
    )
        external
        returns(address core_, address consensusGateway_);
}

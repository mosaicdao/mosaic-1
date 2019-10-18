pragma solidity ^0.5.0;

interface AxiomI {

    /**
     * @notice Deploy proxy contract. This can be called only by consensus
     *         contract.
     * @param _masterCopy Master copy contract address.
     * @param _data Setup function call data.
     * @return Deployed contract address.
     */
    function deployProxyContract(
        address _masterCopy,
        bytes calldata _data
    )
        external
        returns (address deployedAddress_);
}

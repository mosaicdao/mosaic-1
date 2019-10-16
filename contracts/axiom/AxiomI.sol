pragma solidity ^0.5.0;

interface AxiomI {
    function deployProxyContract(
        address masterCopy,
        bytes calldata data
    )
        external
        returns (address deployedAddress_);
}

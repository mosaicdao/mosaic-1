pragma solidity ^0.5.0;

import "../../axiom/AxiomI.sol";
import "../../consensus/Consensus.sol";

contract SpyAxiom is AxiomI{

    address public constant mockedCommitteeAddress = address(111);
    address public constant mockedCoreAddress = address(112);

    bytes public spyNewCommitteeCallData;
    bytes public spyNewCoreCallData;

    function setupConsensus(Consensus _consensus) public  {
        _consensus.setup(
            uint256(100),
            uint256(5),
            uint256(6),
            uint256(99999),
            uint256(200),
            address(1)
        );
    }

    function newCore(
        bytes calldata _data
    )
        external
        returns (address)
    {
        spyNewCoreCallData = _data;
        return mockedCoreAddress;
    }

    function newCommittee(
        bytes calldata _data
    )
        external
        returns (address)
    {
        spyNewCommitteeCallData = _data;
        return mockedCommitteeAddress;
    }

    function callNewMetaChainOnConsensus(
        Consensus _consensus,
        bytes20 _chainId,
        uint256 _epochLength,
        bytes32 _source,
        uint256 _sourceBlockHeight
    )
        external
    {
        _consensus.newMetaChain(
            // TODO: align unit tests
            address(_chainId),
            _epochLength,
            _source,
            _sourceBlockHeight
        );
    }
}

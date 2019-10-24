pragma solidity ^0.5.0;

import "../../axiom/AxiomI.sol";
import "../../consensus/Consensus.sol";

contract SpyAxiom is AxiomI{

    address public constant mockedCommitteeAddress = address(111);

    bytes public spyNewCommitteeCallData;

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
}

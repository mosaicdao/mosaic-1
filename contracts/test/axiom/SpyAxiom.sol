pragma solidity >=0.5.0 <0.6.0;

import "../../axiom/AxiomInterface.sol";
import "../../consensus/Consensus.sol";

contract SpyAxiom is AxiomInterface{

    address public constant mockedCommitteeAddress = address(111);
    address public constant mockedCoreAddress = address(112);
    address public constant mockedAnchorAddress = address(113);
    address public constant mockedConsensusGatewayAddress = address(114);

    bytes public spyNewCommitteeCallData;
    bytes public spyNewCoreCallData;
    bytes public spyNewAnchorCallData;
    bytes public spyNewConsensusGatewayCallData;

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

    function callNewMetachainOnConsensus(
        Consensus _consensus
    )
        external
    {
        _consensus.newMetachain();
    }

    function deployMetachainProxies(
        bytes calldata _coreSetupData,
        bytes calldata _consensusGatewaySetupData
    )
        external
        returns(address core_, address consensusGateway_){

        spyNewCoreCallData = _coreSetupData;
        spyNewConsensusGatewayCallData = _consensusGatewaySetupData;

        core_ = mockedCoreAddress;
        consensusGateway_ = mockedConsensusGatewayAddress;
    }

    function deployAnchor(
        bytes calldata _anchorSetupData
    )
        external
        returns(address anchor_) {
        spyNewAnchorCallData = _anchorSetupData;
        anchor_ = mockedAnchorAddress;
    }

}

pragma solidity >=0.5.0 <0.6.0;

// Copyright 2019 OpenST Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import "./AxiomI.sol";
import "../anchor/Anchor.sol"; // TASK: change this to factory, when new anchor is implemented.
import "../block/Block.sol";
import "../consensus/ConsensusI.sol";
import "../proxies/ProxyFactory.sol";


contract Axiom is AxiomI, ProxyFactory, ConsensusModule {

    /* Usings */

    using SafeMath for uint256;


    /* Events */

    /** Emitted when new metachain is created */
    event MetachainCreated(bytes32 metachainId, address anchor);


    /* Constants */

    /** The callprefix of the Reputation::setup function. */
    bytes4 public constant REPUTATION_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(address,address,uint256,address,uint256,uint256,uint256,uint256)"
        )
    );

    /** The callprefix of the Consensus::setup function. */
    bytes4 public constant CONSENSUS_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(uint256,uint256,uint256,uint256,uint256,address)"
        )
    );


    /* Modifiers */

    modifier onlyTechGov()
    {
        require(
            techGov == msg.sender,
            "Caller must be technical governance address."
        );

        _;
    }


    /* Storage */

    /** Technical governance address */
    address public techGov;

    /** Consensus master copy contract address */
    address public consensusMasterCopy;

    /** Core master copy contract address */
    address public coreMasterCopy;

    /** Committeee master copy contract address */
    address public committeeMasterCopy;

    /** Reputation master copy contract address */
    address public reputationMasterCopy;

    /** Anchor master copy contract address */
    address public anchorMasterCopy;

    /** Consensus gateway master copy contract address */
    address public consensusGatewayMasterCopy;

    /** Reputation contract address */
    ReputationI public reputation;


    /* Special Member Functions */

    /**
     * Constructor for Axiom contract
     *
     * @param _techGov Technical governance address.
     * @param _consensusMasterCopy Consensus master copy contract address.
     * @param _coreMasterCopy Core master copy contract address.
     * @param _committeeMasterCopy Committee master copy contract address.
     * @param _reputationMasterCopy Reputation master copy contract address.
     * @param _anchorMasterCopy Anchor master copy contract address.
     * @param _consensusGatewayMasterCopy Consensus gateway master copy contract address.
     */
    constructor(
        address _techGov,
        address _consensusMasterCopy,
        address _coreMasterCopy,
        address _committeeMasterCopy,
        address _reputationMasterCopy,
        address _anchorMasterCopy,
        address _consensusGatewayMasterCopy
    )
        public
    {
        require(
            _techGov != address(0),
            "Tech gov address is 0."
        );

        require(
            _consensusMasterCopy != address(0),
            "Consensus master copy address is 0."
        );

        require(
            _coreMasterCopy != address(0),
            "Core master copy address is 0."
        );

        require(
            _committeeMasterCopy != address(0),
            "Committee master copy address is 0."
        );

        require(
            _reputationMasterCopy != address(0),
            "Reputation master copy address is 0."
        );

        require(
            _anchorMasterCopy != address(0),
            "Anchor master copy address is 0."
        );

        require(
            _consensusGatewayMasterCopy != address(0),
            "Consensus gateway master copy address is 0."
        );

        techGov = _techGov;
        consensusMasterCopy = _consensusMasterCopy;
        coreMasterCopy = _coreMasterCopy;
        committeeMasterCopy = _committeeMasterCopy;
        reputationMasterCopy = _reputationMasterCopy;
        anchorMasterCopy = _anchorMasterCopy;
        consensusGatewayMasterCopy = _consensusGatewayMasterCopy;
    }


    /* External functions */

    /**
     * @notice Setup consensus contract, this can be only called once by
     *         technical governance address.
     * @param _committeeSize Max committee size that can be formed.
     * @param _minValidators Minimum number of validators that must join a
     *                       created core to open.
     * @param _joinLimit Maximum number of validators that can join in a core.
     * @param _gasTargetDelta Gas target delta to open new metablock.
     * @param _coinbaseSplitPerMille Coinbase split per mille.
     * @param _most MOST token address.
     * @param _stakeMOSTAmount Amount of MOST that will be staked by validators.
     * @param _wETH wEth token address.
     * @param _stakeWETHAmount Amount of wEth that will be staked by validators.
     * @param _cashableEarningsPerMille Fraction of the total amount that can
     *                                  be cashed by validators.
     * @param _initialReputation Initial reputations that will be set when
     *                           validators joins.
     * @param _withdrawalCooldownPeriodInBlocks Cooling period for withdrawal
     *                                          after logout.
     */
    function setupConsensus(
        uint256 _committeeSize,
        uint256 _minValidators,
        uint256 _joinLimit,
        uint256 _gasTargetDelta,
        uint256 _coinbaseSplitPerMille,
        address _most,
        uint256 _stakeMOSTAmount,
        address _wETH,
        uint256 _stakeWETHAmount,
        uint256 _cashableEarningsPerMille,
        uint256 _initialReputation,
        uint256 _withdrawalCooldownPeriodInBlocks
    )
        external
        onlyTechGov
    {
        require(
            address(consensus) == address(0),
            "Consensus is already setup."
        );

        // Deploy the consensus proxy contract.
        // Setup data is blank because setup requires reputation contract address
        // which is deployed in next step.
        Proxy consensusProxy = createProxy(consensusMasterCopy, "");

        ConsensusModule.setupConsensus(ConsensusI(address(consensusProxy)));

        bytes memory reputationSetupData = abi.encodeWithSelector(
            REPUTATION_SETUP_CALLPREFIX,
            consensus,
            _most,
            _stakeMOSTAmount,
            _wETH,
            _stakeWETHAmount,
            _cashableEarningsPerMille,
            _initialReputation,
            _withdrawalCooldownPeriodInBlocks
        );

        reputation = ReputationI(
            address(
                createProxy(
                    reputationMasterCopy,
                    reputationSetupData
                )
            )
        );

        bytes memory consensusSetupData = abi.encodeWithSelector(
            CONSENSUS_SETUP_CALLPREFIX,
            _committeeSize,
            _minValidators,
            _joinLimit,
            _gasTargetDelta,
            _coinbaseSplitPerMille,
            reputation
        );

        callProxyData(consensusProxy, consensusSetupData);
    }

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
        onlyConsensus
        returns (address deployedAddress_)
    {
        return deployProxyContract(coreMasterCopy, _data);
    }

    /**
     * @notice Deploy Committee proxy contract. This can be called only by consensus
     *         contract.
     * @param _data Setup function call data.
     *
     * @return deployedAddress_ Deployed contract address.
     */
    function newCommittee(
        bytes calldata _data
    )
        external
        onlyConsensus
        returns (address deployedAddress_)
    {
        return deployProxyContract(committeeMasterCopy, _data);
    }

    /**
     * @notice Setup a new metachain. Only technical governance address can
     *         call this function.
     *
     * @return metachainId_ Metachain id.
     */
    function newMetaChain()
        external
        onlyTechGov
        returns(bytes32 metachainId_)
    {
        address anchor;

        (metachainId_, anchor) = consensus.newMetaChain();

        emit MetachainCreated(metachainId_, anchor);
    }

    /**
     * @notice Deploys proxy for anchor contract.
     *
     * @param _anchorSetupData Setup data for anchor contract.
     *
     * @return anchor_ Address of anchor contract.
     */
    function deployAnchor(bytes calldata _anchorSetupData)
        external
        onlyConsensus
        returns(address anchor_)
    {
        anchor_ = deployProxyContract(anchorMasterCopy, _anchorSetupData);
    }

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
        onlyConsensus
        returns(address core_, address consensusGateway_)
    {
        core_ = deployProxyContract(coreMasterCopy, _coreSetupData);
        consensusGateway_ = deployProxyContract(
            consensusGatewayMasterCopy,
            _consensusGatewaySetupData
        );
    }


    /* Private Functions */

    /**
     * @notice Deploy proxy contract.
     * @param _masterCopy Master copy contract address.
     * @param _data Setup function call data.
     * @return Deployed contract address.
     */
    function deployProxyContract(
        address _masterCopy,
        bytes memory _data
    )
        private
        returns (address deployedAddress_)
    {
        require(
            _masterCopy != address(0),
            "Master copy address is 0."
        );

        Proxy proxyContract = createProxy(
            _masterCopy,
            _data
        );
        deployedAddress_ = address(proxyContract);
    }
}

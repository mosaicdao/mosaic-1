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

contract Axiom is AxiomI, ProxyFactory {

    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /** Epoch length */
    uint256 public constant EPOCH_LENGTH = uint256(100);

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

    modifier onlyConsensus()
    {
        require(
            address(consensus) == msg.sender,
            "Caller must be consensus address."
        );

        _;
    }

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

    /** Consensus contract address */
    ConsensusI public consensus;

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
     */
    constructor(
        address _techGov,
        address _consensusMasterCopy,
        address _coreMasterCopy,
        address _committeeMasterCopy,
        address _reputationMasterCopy
    )
        public
    {
        require(
            _techGov != address(0),
            "Tech gov address is 0."
        );

        require(
            _consensusMasterCopy != address(0),
            "Consensus master copy adress is 0."
        );

        require(
            _coreMasterCopy != address(0),
            "Core master copy adress is 0."
        );

        require(
            _committeeMasterCopy != address(0),
            "Committee master copy adress is 0."
        );

        require(
            _reputationMasterCopy != address(0),
            "Reputation master copy adress is 0."
        );

        techGov = _techGov;
        consensusMasterCopy = _consensusMasterCopy;
        coreMasterCopy = _coreMasterCopy;
        committeeMasterCopy = _committeeMasterCopy;
        reputationMasterCopy = _reputationMasterCopy;
    }


    /* External functions */

    /**
     * @notice Setup consensus contract, this can be only called once by
     *          technical governance address.
     * @param _committeeSize Max committee size that can be formed.
     * @param _minValidators Minimum number of validators that must join a
     *                       created core to open.
     * @param _joinLimit Maximum number of validators that can join in a core.
     * @param _gasTargetDelta Gas target delta to open new metablock.
     * @param _coinbaseSplitPerMille Coinbase split per mille.
     * @param _mOST mOST token address.
     * @param _stakeMOSTAmount Amount of mOST that will be staked by validators.
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
        address _mOST,
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
        Proxy consensusProxy = createProxy(consensusMasterCopy, "");

        consensus = ConsensusI(address(consensusProxy));

        bytes memory reputationSetupData = abi.encodeWithSelector(
            REPUTATION_SETUP_CALLPREFIX,
            consensus,
            _mOST,
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
     * @return Deployed contract address.
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
     * @notice Setup a new meta chain. Only technical governance address can
     *         call this function.
     * @param _maxStateRoots The max number of state roots to store in the
     *                       circular buffer.
     * @param _rootRlpBlockHeader RLP encoded block header of root block.
     */
    function newMetaChain(
        uint256 _maxStateRoots,
        bytes calldata _rootRlpBlockHeader
    )
        external
        onlyTechGov
    {
        require(
            address(consensus) != address(0),
            "Consensus must be setup."
        );

        bytes32 source = keccak256(_rootRlpBlockHeader);

        Block.Header memory blockHeader = Block.decodeHeader(_rootRlpBlockHeader);

        // Task: When new Anchor is implemented, use proxy pattern for deployment.
        Anchor anchor = new Anchor(
            blockHeader.height,
            blockHeader.stateRoot,
            _maxStateRoots,
            address(consensus)
        );

        consensus.newMetaChain(
            address(anchor),
            EPOCH_LENGTH,
            source,
            blockHeader.height
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
            'Master copy address is 0.'
        );

        Proxy proxyContract = createProxy(
            _masterCopy,
            _data
        );
        deployedAddress_ = address(proxyContract);
    }

    /**
     * @notice Call a function.
     * @param _proxy Proxy contract address.
     * @param _data Function call data.
     */
    function callProxyData(
        Proxy _proxy,
        bytes memory _data
    )
        private
    {
        if (_data.length > 0) {
            // solium-disable-next-line security/no-inline-assembly
            assembly {
                if eq(call(gas, _proxy, 0, add(_data, 0x20), mload(_data), 0, 0), 0) {
                    revert(0, 0)
                }
            }
        }
    }

}

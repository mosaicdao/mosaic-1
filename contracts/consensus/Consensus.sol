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

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./ConsensusI.sol";
import "./CoreLifetime.sol";
import "../anchor/AnchorI.sol";
import "../axiom/AxiomI.sol";
import "../block/Block.sol";
import "../committee/CommitteeI.sol";
import "../core/CoreI.sol";
import "../reputation/ReputationI.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../version/MosaicVersion.sol";
import "../consensus-gateway/ConsensusGatewayI.sol";

contract Consensus is MasterCopyNonUpgradable, CoreLifetimeEnum, MosaicVersion, ConsensusI {

    /* Usings */

    using SafeMath for uint256;


    /* Events */

    event EndpointPublished(
        bytes32 metachainId,
        address core,
        address validator,
        string service,
        string endpoint
    );


    /* Enums */

    /** Used to define the current round of a metablock. */
    enum MetablockRound {
        Undefined,
        Precommitted,
        CommitteeFormed,
        CommitteeDecided,
        Committed
    }


    /* Constants */

    /** Committee formation block delay */
    uint256 public constant COMMITTEE_FORMATION_DELAY = uint8(14);

    /** Committee formation mixing length */
    uint256 public constant COMMITTEE_FORMATION_LENGTH = uint8(7);

    /** Minimum required validators */
    uint256 public constant MIN_REQUIRED_VALIDATORS = uint8(5);

    /** Maximum coinbase split per mille */
    uint256 public constant MAX_COINBASE_SPLIT_PER_MILLE = uint16(1000);

    /** The callprefix of the Core::setup function. */
    bytes4 public constant CORE_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(address,bytes32,uint256,uint256,uint256,address,uint256,bytes32,uint256,uint256,uint256,uint256)"
        )
    );

    string public constant MOSAIC_DOMAIN_SEPARATOR_NAME = "Mosaic-Consensus";

    /** It is domain separator typehash used to calculate metachain id. */
    bytes32 public constant MOSAIC_DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "MosaicDomain(string name,string version,uint256 originChainId,address consensus)"
    );

    /** It is metachain id typehash used to calculate metachain id. */
    bytes32 public constant METACHAIN_ID_TYPEHASH = keccak256(
        "MetachainId(address anchor)"
    );

    /** The callprefix of the Committee::setup function. */
    bytes4 public constant COMMITTEE_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(bytes32,address,uint256,bytes32,bytes32)"
        )
    );

    //todo fix this when consensus gateway is implemented.
    /** The callprefix of the ConsensusGateway::setup function. */
    bytes4 public constant CONSENSUS_GATEWAY_SETUP_CALL_PREFIX = bytes4(
        keccak256(
            "setup()"
        )
    );

    /** The callprefix of the Anchor::setup function.
     *
     *  uint256 - maxStateRoots Max number of state root stored in anchor contract.
     *  address - address of consensus contract.
     */
    bytes4 public constant ANCHOR_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(uint256,address)"
        )
    );

    /* Max number of state roots anchor stores. */
    uint256 public constant ANCHOR_MAX_STATE_ROOTS = 100;

    /** Epoch length */
    uint256 public constant EPOCH_LENGTH = uint256(100);


    /* Structs */

    struct Metablock {
        bytes32 metablockHash;
        MetablockRound round;
        uint256 roundBlockNumber;
    }


    /* Storage */

    /** Committee size */
    uint256 public committeeSize;

    /** Minimum number of validators that must join a created core to open */
    uint256 public minValidators;

    /** Maximum number of validators that can join in a core */
    uint256 public joinLimit;

    /** Gas target delta to open new metablock */
    uint256 public gasTargetDelta;

    /** Coinbase split per mille */
    uint256 public coinbaseSplitPerMille;

    /** Gas price to calculate reward */
    uint256 public feeGasPrice;

    /** Gas limit to calculate reward */
    uint256 public feeGasLimit;

    /** Mapping of a metablock number to a metablock (per metachain).  */
    mapping(bytes32 /* metachain id */ => mapping(uint256 /* metablock height */ => Metablock)) public metablockchains;

    /** Metablocks' tips per metachain. */
    mapping(bytes32 /* metachain id */ => uint256 /* metablock tip */) public metablockTips;

    /** Assigned core for a given metachain id */
    mapping(bytes32 /* metachain id */ => CoreI) public assignments;

    /** Committees per metablock. */
    mapping(bytes32 /* metablock hash */ => CommitteeI) public committees;

    /** Committees' decisions per metablock. */
    mapping(bytes32 /* metablock hash */ => bytes32 /* decision */) public decisions;

    /** Assigned anchor per metachain. */
    mapping(bytes32 /* metachain id */ => AnchorI) public anchors;

    /** Core lifetimes. */
    mapping(address /* core */ => CoreLifetime /* coreLifetime */) public coreLifetimes;

    /** Assigned consensus gateways for a given metachain id */
    mapping(bytes32 => ConsensusGatewayI) public consensusGateways;

    /** Reputation contract for validators */
    ReputationI public reputation;

    /** Axiom contract address */
    AxiomI public axiom;

    /** Mosaic domain separator */
    bytes32 public mosaicDomainSeparator;


    /* Modifiers */

    modifier onlyAxiom()
    {
        require(
            address(axiom) == msg.sender,
            "Caller must be axiom address."
        );

        _;
    }


    /* External functions */

    /**
     * @notice Setup consensus contract. Setup method can be called only once.
     *
     * @dev Function requires:
     *          - Consensus contract should not be already setup.
     *          - Committee size should be greater than 0.
     *          - Minimum validator size must be greater or equal to 5.
     *          - Maximum validator size should be greater or equal to minimum
     *            validator size.
     *          - Gas target delta should be greater than 0.
     *          - Coin base split per mille should be in range: 0..1000.
     *          - Reputation contract address should be 0.
     *
     * @param _committeeSize Max committee size that can be formed.
     * @param _minValidators Minimum number of validators that must join a
     *                       created core to open.
     * @param _joinLimit Maximum number of validators that can join a core.
     * @param _gasTargetDelta Gas target delta to open new metablock.
     * @param _coinbaseSplitPerMille Coinbase split per mille.
     * @param _reputation Reputation contract address.
     */
    function setup(
        uint256 _committeeSize,
        uint256 _minValidators,
        uint256 _joinLimit,
        uint256 _gasTargetDelta,
        uint256 _coinbaseSplitPerMille,
        address _reputation
    )
        external
    {
        // This function must be called only once.
        require(
            address(axiom) == address(0),
            "Consensus is already setup."
        );

        require(
            _committeeSize > 0,
            "Committee size is 0."
        );

        require(
            _minValidators >= uint256(MIN_REQUIRED_VALIDATORS),
            "Min validator size must be greater or equal to 5."
        );

        require(
            _joinLimit >= _minValidators,
            "Max validator size is less than minimum validator size."
        );

        require(
            _gasTargetDelta > 0,
            "Gas target delta is 0."
        );

        require(
            _coinbaseSplitPerMille <= MAX_COINBASE_SPLIT_PER_MILLE,
            "Coin base split per mille should be in range: 0..1000."
        );

        require(
            _reputation != address(0),
            "Reputation contract address is 0."
        );

        committeeSize = _committeeSize;
        minValidators = _minValidators;
        joinLimit = _joinLimit;
        gasTargetDelta = _gasTargetDelta;
        coinbaseSplitPerMille = _coinbaseSplitPerMille;
        reputation = ReputationI(_reputation);

        axiom = AxiomI(msg.sender);

        uint256 chainId = getChainId();

        mosaicDomainSeparator = keccak256(
            abi.encode(
                MOSAIC_DOMAIN_SEPARATOR_TYPEHASH,
                MOSAIC_DOMAIN_SEPARATOR_NAME,
                DOMAIN_SEPARATOR_VERSION,
                chainId,
                address(this)
            )
        );

        feeGasPrice = uint256(0);
        feeGasLimit = uint256(0);
    }

    /**
     * @notice Precommits a metablock.
     *
     * @dev Function requires:
     *          - the given metachain id is not 0
     *          - the given metablock's hash is not 0
     *          - the given metablock's height is +1 of the current
     *            height of the metablockchain
     *          - the caller is the assigned core of the metablockchain
     *          - the caller (core) is running
     *          - the current (tip) metablock of the metablockchain is committed
     */
    function precommitMetablock(
        bytes32 _metachainId,
        uint256 _metablockHeight,
        bytes32 _metablockHashPrecommit
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        require(
            _metablockHashPrecommit != bytes32(0),
            "Metablock hash is 0."
        );

        CoreI core = assignments[_metachainId];

        require(
            msg.sender == address(core),
            "Caller is not an assigned core for the given metablockchain."
        );

        require(
            isCoreRunning(core),
            "Core (caller) is not running."
        );

        uint256 currentHeight = metablockTips[_metachainId];
        Metablock storage currentMetablock = metablockchains[_metachainId][currentHeight];

        require(
            currentHeight.add(1) == _metablockHeight,
            "A precommit must append to the metablockchain."
        );

        require(
            currentMetablock.round == MetablockRound.Committed,
            "Current metablock must be committed."
        );

        Metablock storage nextMetablock = metablockchains[_metachainId][_metablockHeight];

        assert(nextMetablock.round == MetablockRound.Undefined);

        nextMetablock.metablockHash = _metablockHashPrecommit;
        nextMetablock.round = MetablockRound.Precommitted;
        nextMetablock.roundBlockNumber = block.number;

        metablockTips[_metachainId] = _metablockHeight;

        // On first precommit by a core, CoreLifetime state will change to active.
        if (coreLifetimes[address(core)] == CoreLifetime.genesis) {
            coreLifetimes[address(core)] = CoreLifetime.active;
        }
    }

    /**
     * @notice Forms a new committee to verify the precommit.
     *
     * @dev Function requires:
     *          - the given metachain id is not 0
     *          - assigned core has precommitted a metablock
     *          - committee formation height passed
     *          - committee formation blocksegment must be in the most
     *            recent 256 blocks.
     */
    function formCommittee(bytes32 _metachainId)
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        uint256 currentHeight = metablockTips[_metachainId];
        Metablock storage currentMetablock = metablockchains[_metachainId][currentHeight];

        require(
            currentMetablock.round == MetablockRound.Precommitted,
            "Assigned core must have precommitted a metablock to form a committee."
        );

        currentMetablock.round = MetablockRound.CommitteeFormed;
        currentMetablock.roundBlockNumber = block.number;

        uint256 committeeFormationBlockHeight = currentMetablock.roundBlockNumber.add(
            COMMITTEE_FORMATION_LENGTH
        );

        require(
            block.number > committeeFormationBlockHeight,
            "Committee formation height has not yet come to pass."
        );

        bytes32 seed = hashBlockSegment(
            currentMetablock.roundBlockNumber,
            committeeFormationBlockHeight
        );

        startCommittee(_metachainId, seed, currentMetablock.metablockHash);
    }

    /**
     * @notice Enters a validator into a committee.
     *
     * @dev Function requires:
     *          - the given metachain id is not 0
     *          - the given core's address is not 0
     *          - the given validator's address is not 0
     *          - the given 'further' validator's address is not 0
     *          - the given core is running
     *          - valid validator is given
     *              - is active in the given core
     *              - has not been slashed
     *          - the corresponding metablock's round is 'CommitteeFormed'
     *
     * @param _metachainId Metachain id for the committee to enter.
     * @param _validator Validator address to enter.
     * @param _furtherMember Validator address that is further member
     *                       compared to the `_validator` address
     */
    function enterCommittee(
        bytes32 _metachainId,
        CoreI _core,
        address _validator,
        address _furtherMember
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        require(
            _core != CoreI(0),
            "Core's address is 0."
        );

        require(
            _validator != address(0),
            "Validator's address is 0."
        );

        require(
            _furtherMember != address(0),
            "Further validator's address is 0."
        );

        require(
            isCoreRunning(_core),
            "The given core is not running."
        );

        require(
            isValidator(_core, _validator),
            "Invalid validator was given."
        );

        uint256 currentHeight = metablockTips[_metachainId];
        Metablock storage currentMetablock = metablockchains[_metachainId][currentHeight];

        require(
            currentMetablock.round == MetablockRound.CommitteeFormed,
            "Committee must have been formed to enter a validator."
        );

        CommitteeI committee = committees[currentMetablock.metablockHash];
        assert(committee != CommitteeI(0));

        committee.enterCommittee(_validator, _furtherMember);
    }

    /**
     * @notice Registers committee decision.
     *
     * @param _committeeDecision Decision of a caller committee.
     */
    function registerCommitteeDecision(
        bytes32 _metachainId,
        bytes32 _committeeDecision
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        require(
            _committeeDecision != bytes32(0),
            "Committee decision is 0."
        );

        uint256 currentHeight = metablockTips[_metachainId];
        Metablock storage currentMetablock = metablockchains[_metachainId][currentHeight];

        require(
            currentMetablock.round == MetablockRound.CommitteeFormed,
            "Committee must have been formed to register a decision."
        );

        currentMetablock.round = MetablockRound.CommitteeDecided;
        currentMetablock.roundBlockNumber = block.number;

        address committee = address(committees[currentMetablock.metablockHash]);
        require(
            committee == msg.sender,
            "Wrong committee calls."
        );

        require(
            decisions[currentMetablock.metablockHash] == bytes32(0),
            "Committee's decision has been already registered."
        );

        decisions[currentMetablock.metablockHash] = _committeeDecision;
    }

    /**
     * @notice Commits a metablock.
     *
     * @dev Function requires:
     *          - block header should match with source blockhash
     *          - metachain id should not be 0
     *          - a core for the specified metachain id should exist
     *          - precommit for the corresponding core should exist
     *          - committee should have been formed for the precommit
     *          - committee decision should match with the specified
     *            committee lock
     *          - committee decision should match with the core's precommit
     *          - the given metablock parameters should match with the
     *            core's precommit.
     *          - anchor contract for the given metachain id should exist
     *
     * @param _metachainId Metachain id.
     * @param _rlpBlockHeader RLP ecoded block header.
     * @param _kernelHash Kernel hash
     * @param _originObservation Observation of the origin chain.
     * @param _dynasty The dynasty number where the meta-block closes
     *                 on the auxiliary chain.
     * @param _accumulatedGas The total consumed gas on auxiliary within this
     *                        meta-block.
     * @param _committeeLock The committee lock that hashes the transaction
     *                       root on the auxiliary chain.
     * @param _source Source block hash.
     * @param _target Target block hash.
     * @param _sourceBlockHeight Source block height.
     * @param _targetBlockHeight Target block height.
     */
    function commitMetablock(
        bytes32 _metachainId,
        bytes calldata _rlpBlockHeader,
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        external
    {
        require(
            _source == keccak256(_rlpBlockHeader),
            "Block header does not match with vote message source."
        );

        uint256 currentHeight = metablockTips[_metachainId];
        Metablock storage currentMetablock = metablockchains[_metachainId][currentHeight];

        require(
            currentMetablock.round == MetablockRound.CommitteeDecided,
            "Committee has not decided on a proposal yet."
        );

        currentMetablock.round = MetablockRound.Committed;
        currentMetablock.roundBlockNumber = block.number;

        CoreI core = assignments[_metachainId];
        require(
            isCoreActive(core),
            "Core is not active."
        );

        assertCommit(
            core,
            currentMetablock.metablockHash,
            _kernelHash,
            _originObservation,
            _dynasty,
            _accumulatedGas,
            _committeeLock,
            _source,
            _target,
            _sourceBlockHeight,
            _targetBlockHeight
        );

        // Anchor state root.
        anchorStateRoot(_metachainId, _rlpBlockHeader);

        // Open a new metablock.
        core.openMetablock(
            _dynasty,
            _accumulatedGas,
            _sourceBlockHeight,
            gasTargetDelta
        );
    }

    /**
     * @notice Validator joins the core, when core lifetime status is genesis
     *         or active. This is called by validator address.
     *
     * @dev Function requires:
     *          - Core should exist for given metachain
     *          - core lifetime status must be genesis or active
     *
     * @param _metachainId Metachain id that validator wants to join.
     * @param _withdrawalAddress A withdrawal address of newly joined validator.
     */
    function join(
        bytes32 _metachainId,
        address _withdrawalAddress
    )
        external
    {
        CoreI core = assignments[_metachainId];

        require(
            core != CoreI(0),
            "Core does not exist for given metachain."
        );

        require(
            isCoreRunning(core),
            "Core lifetime status must be genesis or active."
        );

        // Stake in reputation contract.
        reputation.stake(msg.sender, _withdrawalAddress);

        // Join in core contract.
        core.join(msg.sender);
    }

    /**
     * @notice Validator joins the core, when core lifetime status is creation.
     *         This is called by validator address.
     *
     * @dev Function requires:
     *          - core should exist for given metachain
     *          - core life time should be in creation state
     *
     * @param _metachainId Metachain id that validator wants to join.
     * @param _withdrawalAddress A withdrawal address of newly joined validator.
     */

    function joinDuringCreation(
        bytes32 _metachainId,
        address _withdrawalAddress
    )
        external
    {
        CoreI core = assignments[_metachainId];

        require(
            core != CoreI(0),
            "Core does not exist for given metachain."
        );

        // Specified core must have creation lifetime status.
        require(
            coreLifetimes[address(core)] == CoreLifetime.creation,
            "Core lifetime status must be creation."
        );

        // Stake in reputation contract.
        reputation.stake(msg.sender, _withdrawalAddress);

        // Join in core contract.
        (
            uint256 validatorCount,
            uint256 minValidatorCount
        ) = core.joinBeforeOpen(msg.sender);

        if (validatorCount >= minValidatorCount) {
            coreLifetimes[address(core)] = CoreLifetime.genesis;
            ConsensusGatewayI consensusGateway = consensusGateways[_metachainId];
            assert(address(consensusGateway) != address(0));
            consensusGateway.declareOpenKernel(
                address(core),
                feeGasPrice,
                feeGasLimit
            );
        }
    }

    /**
     * @notice Validator logs out. This is called by validator address.
     *
     * @dev Function requires:
     *          - metachain id should not be 0.
     *          - core address should not be 0.
     *          - core should be assigned for the specified metachain id.
     *          - core for the specified metachain id should exist.
     *
     * @param _metachainId Metachain id that validator wants to logout.
     * @param _core Core address that validator wants to logout.
     */
    function logout(
        bytes32 _metachainId,
        CoreI _core
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        require(
            _core != CoreI(0),
            "Core is 0."
        );

        require(
            assignments[_metachainId] == _core,
            "Core is not assigned for the specified metachain id."
        );

        require(
            isCoreRunning(_core),
            "Core lifetime status must be genesis or active."
        );

        _core.logout(msg.sender);

        reputation.deregister(msg.sender);
    }

    /** @notice Creates a new meta chain.
     *         This can be called only by axiom.
     *
     * @dev Function requires:
     *          - msg.sender should be axiom contract.
     *          - core is not assigned to metachain.
     */
    function newMetaChain()
        external
        onlyAxiom
        returns(bytes32 metachainId_)
    {

        bytes memory anchorSetupCallData = anchorSetupData(
            ANCHOR_MAX_STATE_ROOTS,
            address(this)
        );

        AnchorI anchor = AnchorI(axiom.deployAnchor(anchorSetupCallData));
        metachainId_ = hashMetachainId(address(anchor));

        bytes memory coreSetupCallData = coreSetupData(
            metachainId_,
            EPOCH_LENGTH,
            uint256(0), // metablock height
            bytes32(0), // parent hash
            gasTargetDelta, // gas target
            uint256(0), // dynasty
            uint256(0), // accumulated gas
            0 // source block height
        );

        bytes memory consensusGatewaySetupCallData = consensusGatewaySetupData();

        (
            address core,
            address consensusGateway
        ) = axiom.deployMetachainProxies(
                coreSetupCallData,
                consensusGatewaySetupCallData
            );

        assignments[metachainId_] = CoreI(core);
        anchors[metachainId_] = anchor;
        consensusGateways[metachainId_] = ConsensusGatewayI(consensusGateway);

        coreLifetimes[core] = CoreLifetime.creation;
    }

    /** Get minimum validator and join limit count. */
    function coreValidatorThresholds()
        external
        view
        returns (uint256 minimumValidatorCount_, uint256 joinLimit_)
    {
        minimumValidatorCount_ = minValidators;
        joinLimit_ = joinLimit;
    }
    // Task: Pending functions related to halting and corrupting of core.

    /**
     * @notice It publishes the endpoint.
     *
     * @dev Function requires:
     *          - only validator can call.
     *          - validator is not slashed.
     *          - metachain id should be valid.
     *
     * @param _metachainId Metachain id.
     * @param _service Service can be ipfs, enode, etc.
     * @param _endpoint Url for the service.
     */
    function publishEndpoint(
        bytes32 _metachainId,
        string calldata _service,
        string calldata _endpoint
    )
        external
    {
        CoreI core = assignments[_metachainId];

        require(
            core != CoreI(0),
            "No core exists for the metachain id."
        );

        require(
            isValidator(core, msg.sender),
            "Invalid validator was given."
        );

        emit EndpointPublished(
            _metachainId,
            address(core),
            msg.sender,
            _service,
            _endpoint
        );
    }


    /* Public functions */

    /**
     * @notice Gets metachain id.
     *         Metachain id format :
     *         `0x19 0x4d <mosaic-domain-separator> <metachainid-typehash>` where
     *         0x19 signed data as per EIP-191.
     *         0x4d is version byte for Mosaic.
     *         <mosaic-domain-separator> format is `MosaicDomain(string name,
     *                            string version,uint256 originChainId,
     *                            address consensus)`.
     *         <metachainid-typehash> format is MetachainId(address anchor).
     *
     *         <mosaic-domain-separator> and <metachainid-typehash> is EIP-712
     *         complaint.
     * @param _anchor Anchor address of the new metachain.
     *
     * @return metachainId_ Metachain id.
     */
    function hashMetachainId(address _anchor)
        public
        view
        returns(bytes32 metachainId_)
    {
        require(
            address(_anchor) != address(0),
            "Anchor address must not be 0."
        );

        bytes32 metachainIdHash = keccak256(
            abi.encode(
                METACHAIN_ID_TYPEHASH,
                _anchor
            )
        );

        metachainId_ = keccak256(
            abi.encodePacked(
                byte(0x19), // Standard ethereum prefix as per EIP-191.
                byte(0x4d), // 'M' for Mosaic.
                mosaicDomainSeparator,
                metachainIdHash
            )
        );
    }


    /* Internal functions */

    /**
     * @notice Check if the core lifetime state is genesis or active.
     * @param _core Core contract address.
     * Returns true if the specified address is a core.
     */
    function isCoreRunning(CoreI _core)
        internal
        view
        returns (bool)
    {
        CoreLifetime lifeTimeStatus = coreLifetimes[address(_core)];
        return lifeTimeStatus == CoreLifetime.genesis ||
            lifeTimeStatus == CoreLifetime.active;
    }

    function isCoreActive(CoreI _core)
        internal
        view
        returns (bool isActive_)
    {
        isActive_ = coreLifetimes[address(_core)] == CoreLifetime.active;
    }

    function getChainId()
        internal
        pure
        returns(uint256 chainId_)
    {
        assembly {
            chainId_ := chainid()
        }
    }

    /**
     * @notice Starts a new committee.
     *
     * @param _metachainId Metachain id of a proposed metablock.
     * @param _dislocation Hash to shuffle validators.
     * @param _metablockHash Proposal under consideration for committee.
     */
    function startCommittee(
        bytes32 _metachainId,
        bytes32 _dislocation,
        bytes32 _metablockHash
    )
        internal
    {
        assert(committees[_metablockHash] == CommitteeI(0));

        committees[_metablockHash] = newCommittee(
            _metachainId,
            committeeSize,
            _dislocation,
            _metablockHash
        );
    }

    /**
     * @notice isValidator() function checks if the given validator is an
     *         active validator in the given core and has not been slashed.
     *
     * @param _core Core to check the validator against.
     * @param _validator Validator's address to check.
     *
     * @return Returns true, if the given validator is an active validator
     *         in the given core and has not been slashed.
     */
    function isValidator(CoreI _core, address _validator)
        internal
        view
        returns (bool isValidator_)
    {
        assert(_core != CoreI(0));

        isValidator_ = _core.isValidator(_validator)
            && !reputation.isSlashed(_validator);
    }


    /* Private functions */

    function assertCommit(
        CoreI _core,
        bytes32 _precommit,
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        private
        view
    {
        bytes32 decision = decisions[_precommit];

        require(
            _committeeLock == keccak256(abi.encode(decision)),
            "Committee decision does not match with committee lock."
        );

        bytes32 metablockHash = CoreI(_core).hashMetablock(
            _kernelHash,
            _originObservation,
            _dynasty,
            _accumulatedGas,
            _committeeLock,
            _source,
            _target,
            _sourceBlockHeight,
            _targetBlockHeight
        );

        require(
            metablockHash == _precommit,
            "Input parameters do not hash to the core's precommit."
        );
    }

    /**
     * @notice Anchor a new state root for specified metachain id.

     * @dev Function requires:
     *          - anchor for specified metachain id should exist.
     *
     * @param _metachainId Metachain id.
     * @param _rlpBlockHeader RLP encoded block header
     */
    function anchorStateRoot(
        bytes32 _metachainId,
        bytes memory _rlpBlockHeader
    )
        private
    {
        AnchorI anchor = anchors[_metachainId];

        require(
            anchor != AnchorI(0),
            "There is no anchor for the specified metachain id."
        );

        Block.Header memory blockHeader = Block.decodeHeader(_rlpBlockHeader);

        // Anchor state root.
        anchor.anchorStateRoot(
            blockHeader.height,
            blockHeader.stateRoot
        );
    }

    /**
     * @notice Deploys a new core contract.
     * @param _metachainId Metachain id for which the core should be deployed.
     * @param _epochLength Epoch length for new core.
     * @param _height Kernel height.
     * @param _parent Kernel parent hash.
     * @param _gasTarget Gas target to close the meta block.
     * @param _dynasty Committed dynasty number.
     * @param _accumulatedGas Accumulated gas.
     * @param _sourceBlockHeight Source block height.
     *
     * returns Deployed core contract address.
     */
    function coreSetupData(
        bytes32 _metachainId,
        uint256 _epochLength,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        uint256 _sourceBlockHeight
    )
        private
        view
        returns (bytes memory coreSetupCallData_)
    {
        coreSetupCallData_ = abi.encodeWithSelector(
            CORE_SETUP_CALLPREFIX,
            address(this),
            _metachainId,
            _epochLength,
            minValidators,
            joinLimit,
            address(reputation),
            _height,
            _parent,
            _gasTarget,
            _dynasty,
            _accumulatedGas,
            _sourceBlockHeight
        );
    }

    /**
     * Creates anchor setup data.
     *
     * @param _maxStateRoots Maximum stateroots core can store.
     * @param _consensus Address of consensus contract.
     */
    function anchorSetupData(
        uint256 _maxStateRoots,
        address _consensus
    )
        private
        pure
        returns (bytes memory anchorSetupCallData_)
    {
        anchorSetupCallData_ = abi.encodeWithSelector(
            ANCHOR_SETUP_CALLPREFIX,
            _maxStateRoots,
            _consensus
        );
    }

    /**
     * Creates consensus gateway setup data.
     */
    function consensusGatewaySetupData()
        private
        pure
        returns(bytes memory consensusGatewaySetupCallData_)
    {
        // todo implement this after consensus gateway implementation.
        consensusGatewaySetupCallData_ = abi.encodeWithSelector(
            CONSENSUS_GATEWAY_SETUP_CALL_PREFIX
        );
    }

    /**
     * @notice Deploys a new committee contract.
     *
     * @param _metachainId Metachain id of the proposed metablock.
     * @param _committeeSize Committee size.
     * @param _dislocation Hash to shuffle validators.
     * @param _proposal Proposal under consideration for committee.
     *
     * @return Contract address of new deployed committee contract.
     */
    function newCommittee(
        bytes32 _metachainId,
        uint256 _committeeSize,
        bytes32 _dislocation,
        bytes32 _proposal
    )
        private
        returns (CommitteeI committee_)
    {
        bytes memory committeeSetupData = abi.encodeWithSelector(
            COMMITTEE_SETUP_CALLPREFIX,
            _metachainId,
            address(this),
            _committeeSize,
            _dislocation,
            _proposal
        );

        committee_ = CommitteeI(axiom.newCommittee(committeeSetupData));
    }

    /**
     * @notice hashBlockSegment() function calculates a seed based on the
     *         given sengment (start, end].
     *
     * @param start Start block number (not included in the segment).
     * @param end End block number (included in the segment).
     *
     * @return Returns a seed based on the blockhashes of the given blocksegment.
     */
    function hashBlockSegment(
        uint256 start,
        uint256 end
    )
        private
        view
        returns (bytes32 seed_)
    {
        require(
            block.number >= end && block.number < start.add(uint256(256)),
            "Blocksegment is not in the most recent 256 blocks."
        );

        uint256 length = end.sub(start);

        bytes32[] memory seedGenerator = new bytes32[](length);

        for (uint256 i = 0; i < length; i = i.add(1)) {
            seedGenerator[i] = blockhash(start + i + 1);
        }

        seed_ = keccak256(
            abi.encodePacked(seedGenerator)
        );
    }
}

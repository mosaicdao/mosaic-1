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
import "../core/CoreStatusEnum.sol";
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


    /* Constants */

    /** Committee formation block delay */
    uint256 public constant COMMITTEE_FORMATION_DELAY = uint8(14);

    /** Committee formation mixing length */
    uint256 public constant COMMITTEE_FORMATION_LENGTH = uint8(7);

    /** Sentinel pointer for marking end of linked-list of committees */
    address public constant SENTINEL_COMMITTEES = address(0x1);

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
            "setup(address,uint256,bytes32,bytes32)"
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

    /** Precommit from core for a next metablock */
    struct Precommit {
        bytes32 proposal;
        uint256 committeeFormationBlockHeight;
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

    /** Block hash of heads of Metablockchains */
    mapping(bytes32 /* metachainId */ => bytes32 /* MetablockHash */) public metablockHeaderTips;

    /** Core statuses */
    mapping(address /* core */ => CoreLifetime /* coreLifetime */) public coreLifetimes;

    /** Assigned core for a given metachain id */
    mapping(bytes32 /* metachainId */ => address /* core */) public assignments;

    /** Precommitts from cores for metablockchains. */
    mapping(address /* core */ => Precommit) public precommits;

    /** Precommits under consideration of committees. */
    mapping(bytes32 /* precommit */ => CommitteeI /* committee */) public proposals;

    /** Precommits under consideration of committees. */
    mapping(address /* committee */ => bytes32 /* commit */) public decisions;

    /** Linked-list of committees */
    mapping(address => address) public committees;

    /** Assigned anchor for a given metachain id */
    mapping(bytes32 => address) public anchors;

    /** Assigned consensus gateways for a given metachain id */
    mapping(bytes32 => ConsensusGatewayI) public consensusGateways;

    /** Reputation contract for validators */
    ReputationI public reputation;

    /** Axiom contract address */
    AxiomI public axiom;

    /** Mosaic domain separator */
    bytes32 public mosaicDomainSeparator;


    /* Modifiers */

    modifier onlyCore()
    {
        require(
            isCoreRunning(msg.sender),
            "Caller must be an active core."
        );

        _;
    }

    modifier onlyAxiom()
    {
        require(
            address(axiom) == msg.sender,
            "Caller must be axiom address."
        );

        _;
    }

    modifier onlyCommittee()
    {
        require(
            committees[msg.sender] != address(0),
            "Caller must be a committee address."
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

        committees[SENTINEL_COMMITTEES] = SENTINEL_COMMITTEES;

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
     *          - only an active core can call
     *          - precommit is not 0
     *          - there is no precommit under a consideration of a committees
     *            by the core
     */
    function precommitMetablock(bytes32 _proposal)
        external
        onlyCore
    {
        require(
            _proposal != bytes32(0),
            "Proposal is 0."
        );

        Precommit storage precommit = precommits[msg.sender];
        require(
            precommit.proposal == bytes32(0),
            "There already exists a precommit of the core."
        );

        // On first precommit by a core, CoreLifetime state will change to active.
        if (coreLifetimes[msg.sender] == CoreLifetime.genesis) {
            coreLifetimes[msg.sender] = CoreLifetime.active;
        }

        precommit.proposal = _proposal;
        precommit.committeeFormationBlockHeight = block.number.add(
            uint256(COMMITTEE_FORMATION_DELAY)
        );
    }

    /**
     * @notice Forms a new committee to verify the precommit proposal.
     *
     * @dev Function requires:
     *          - core has precommitted
     *          - the current block height is bigger than the precommitt's
     *            committee formation height
     *          - committee formation blocksegment must be in the most
     *            recent 256 blocks.
     *
     * @param _core Core contract address.
     */
    function formCommittee(address _core)
        external
    {
        require(
            coreLifetimes[_core] == CoreLifetime.active,
            "Core lifetime status must be active"
        );

        Precommit storage precommit = precommits[_core];
        require(
            precommit.proposal != bytes32(0),
            "Core has not precommitted."
        );

        require(
            block.number > precommit.committeeFormationBlockHeight,
            "Block height must be higher than set committee formation height."
        );

        require(
            block.number <= precommit.committeeFormationBlockHeight
                .sub(COMMITTEE_FORMATION_LENGTH)
                .add(uint256(256)),
            "Committee formation blocksegment is not in most recent 256 blocks."
        );

        uint256 segmentHeight = precommit.committeeFormationBlockHeight;
        bytes32[] memory seedGenerator = new bytes32[](uint256(COMMITTEE_FORMATION_LENGTH));
        for (uint256 i = 0; i < COMMITTEE_FORMATION_LENGTH; i = i.add(1)) {
            seedGenerator[i] = blockhash(segmentHeight);
            segmentHeight = segmentHeight.sub(1);
        }

        bytes32 seed = keccak256(
            abi.encodePacked(seedGenerator)
        );

        startCommittee(seed, precommit.proposal);
    }

    /**
     * @notice Enters a validator into a committee.
     *
     * @dev Function requires:
     *          - the committee exists
     *          - the validator is active
     * 			- the validator is not slashed
     *
     * @param _committeeAddress Committee address that validator wants to enter.
     * @param _validator Validator address to enter.
     * @param _furtherMember Validator address that is further member
     *                       compared to the `_validator` address
     */
    function enterCommittee(
        address _committeeAddress,
        address _validator,
        address _furtherMember
    )
        external
    {
        require(
            committees[_committeeAddress] != address(0),
            "Committee does not exist."
        );

        require(
            !reputation.isSlashed(_validator),
            "Validator is slashed."
        );

        CommitteeI committee = CommitteeI(_committeeAddress);
        committee.enterCommittee(_validator, _furtherMember);
    }

    /**
     * @notice Registers committee decision.
     *
     * @dev Function requires:
     *          - only committee can call
     *          - committee has not yet registered its decision
     *
     * @param _committeeDecision Decision of a caller committee.
     */
    function registerCommitteeDecision(
        bytes32 _committeeDecision
    )
        external
        onlyCommittee
    {
        require(
            decisions[msg.sender] == bytes32(0),
            "Committee's decision has been registered."
        );

        decisions[msg.sender] = _committeeDecision;
    }

    /**
     * @notice Commits a metablock.
     *
     * @dev Function requires:
     *          - block header should match with source blockhash
     *          - metachain id should not be 0
     *          - a core for the specified chain id should exist
     *          - precommit for the corresponding core should exist
     *          - committee should have been formed for the precommit
     *          - committee decision should match with the specified
     *            committee lock
     *          - committee decision should match with the core's precommit
     *          - the given metablock parameters should match with the
     *            core's precommit.
     *          - anchor contract for the given chain id should exist
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

        // Makes sure that assigned core is active.
        address core = assignments[_metachainId];
        require(
            coreLifetimes[core] == CoreLifetime.active,
            "Core lifetime status must be active"
        );

        assertCommit(
            core,
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
        CoreI(core).openMetablock(
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
        address core = assignments[_metachainId];
        require(
            core != address(0),
            "Core does not exist for given metachain."
        );

        require(
            isCoreRunning(core),
            "Core lifetime status must be genesis or active."
        );

        // Stake in reputation contract.
        reputation.stake(msg.sender, _withdrawalAddress);

        // Join in core contract.
        CoreI(core).join(msg.sender);
    }

    /**
     * @notice Validator joins the core, when core lifetime status is creation.
     *         This is called by validator address.
     *
     * @dev Function requires:
     *          - Core should exist for given metachain
     *          - core life time status must be creation
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
        address core = assignments[_metachainId];
        require(
            core != address(0),
            "Core does not exist for given metachain."
        );

        // Specified core must have creation lifetime status.
        require(
            coreLifetimes[core] == CoreLifetime.creation,
            "Core lifetime status must be creation."
        );

        // Stake in reputation contract.
        reputation.stake(msg.sender, _withdrawalAddress);

        // Join in core contract.
        (uint256 validatorCount, uint256 minValidatorCount) =
            CoreI(core).joinDuringCreation(msg.sender);

        if (validatorCount >= minValidatorCount) {
            coreLifetimes[core] = CoreLifetime.genesis;
            ConsensusGatewayI consensusGateway = consensusGateways[_metachainId];
            require(
                address(consensusGateway) != address(0),
                "Consensus gateway does not exist for given metachain."
            );

            consensusGateway.declareOpenKernel(
                core,
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
     *          - core should be assigned for the specified chain id.
     *          - core for the specified chain id should exist.
     *
     * @param _metachainId Metachain id that validator wants to logout.
     * @param _core Core address that validator wants to logout.
     */
    function logout(
        bytes32 _metachainId,
        address _core
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id is 0."
        );

        require(
            _core != address(0),
            "Core address is 0."
        );

        require(
            assignments[_metachainId] == _core,
            "Core is not assigned for the specified metachain id."
        );

        require(
            isCoreRunning(_core),
            "Core lifetime status must be genesis or active."
        );

        CoreI(_core).logout(msg.sender);
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

        address anchor = axiom.deployAnchor(anchorSetupCallData);
        metachainId_ = hashMetachainId(anchor);

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

        (address core, address consensusGateway) =
            axiom.deployMetachainProxies(
                coreSetupCallData,
                consensusGatewaySetupCallData
            );

        assignments[metachainId_] = core;
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
        address core = assignments[_metachainId];
        require(
            core != address(0),
            "No core exists for the metachain id."
        );

        require(
            CoreI(core).isValidator(msg.sender),
            "Validator is not active."
        );

        require(
            !reputation.isSlashed(msg.sender),
            "Validator is slashed."
        );

        emit EndpointPublished(
            _metachainId,
            core,
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
    function isCoreRunning(address _core)
        internal
        view
        returns (bool)
    {
        CoreLifetime lifeTimeStatus = coreLifetimes[_core];
        return lifeTimeStatus == CoreLifetime.genesis ||
            lifeTimeStatus == CoreLifetime.active;
    }

    /**
     * It returns chain id.
     */
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
     * @notice Start a new committee.

     * @dev Function requires:
     *          - committee for the proposal should not exist.
     *
     * @param _dislocation Hash to shuffle validators.
     * @param _proposal Proposal under consideration for committee.
     */
    function startCommittee(
        bytes32 _dislocation,
        bytes32 _proposal
    )
        internal
    {
        require(
            proposals[_proposal] == CommitteeI(0),
            "There already exists a committee for the proposal."
        );

        CommitteeI committee_ = newCommittee(committeeSize, _dislocation, _proposal);
        committees[address(committee_)] = committees[SENTINEL_COMMITTEES];
        committees[SENTINEL_COMMITTEES] = address(committee_);

        proposals[_proposal] = committee_;
    }


    /* Private functions */

    function assertCommit(
        address _core,
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
    {
        bytes32 precommit = precommits[_core].proposal;

        require(
            precommit != bytes32(0),
            "Core has not precommitted."
        );

        // Delete the precommit. This will avoid any re-entrancy with same params.
        delete precommits[_core];

        address committee = address(proposals[precommit]);
        require(
            committee != address(0),
            "Committee has not been formed for precommit."
        );

        bytes32 decision = decisions[committee];

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
            metablockHash == precommit,
            "Input parameters do not hash to the core's precommit."
        );
    }

    /**
     * @notice Anchor a new state root for specified metachain id.

     * @dev Function requires:
     *          - anchor for specified metachain id should exist.
     *
     * @param _metachainId Chain id.
     * @param _rlpBlockHeader RLP encoded block header
     */
    function anchorStateRoot(
        bytes32 _metachainId,
        bytes memory _rlpBlockHeader
    )
        private
    {
        address anchorAddress = anchors[_metachainId];
        require(
            anchorAddress != address(0),
            "There is no anchor for the specified metachain id."
        );

        Block.Header memory blockHeader = Block.decodeHeader(_rlpBlockHeader);

        // Anchor state root.
        AnchorI(anchorAddress).anchorStateRoot(
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
     * @notice Deploy a new committee contract.
     * @param _committeeSize Committee size.
     * @param _dislocation Hash to shuffle validators.
     * @param _proposal Proposal under consideration for committee.
     * returns Contract address of new deployed committee contract.
     */
    function newCommittee(
        uint256 _committeeSize,
        bytes32 _dislocation,
        bytes32 _proposal
    )
        private
        returns (CommitteeI committee_)
    {
        bytes memory committeeSetupData = abi.encodeWithSelector(
            COMMITTEE_SETUP_CALLPREFIX,
            address(this),
            _committeeSize,
            _dislocation,
            _proposal
        );

        address committeeAddress = axiom.newCommittee(
            committeeSetupData
        );

        committee_ = CommitteeI(committeeAddress);
    }
}

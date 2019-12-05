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
import "../anchor/AnchorI.sol";
import "../axiom/AxiomI.sol";
import "../block/Block.sol";
import "../committee/CommitteeI.sol";
import "../core/CoreI.sol";
import "../core/CoreStatusEnum.sol";
import "../reputation/ReputationI.sol";
import "../proxies/MasterCopyNonUpgradable.sol";

contract Consensus is MasterCopyNonUpgradable, CoreStatusEnum, ConsensusI {

    /* Usings */

    using SafeMath for uint256;


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
            "setup(address,bytes20,uint256,uint256,uint256,address,uint256,bytes32,uint256,uint256,uint256,bytes32,uint256)"
        )
    );

    /** The callprefix of the Committee::setup function. */
    bytes4 public constant COMMITTEE_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(address,uint256,bytes32,bytes32)"
        )
    );


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

    /** Block hash of heads of Metablockchains */
    mapping(bytes20 /* chainId */ => bytes32 /* MetablockHash */) public metablockHeaderTips;

    /** Core statuses */
    mapping(address /* core */ => CoreStatus /* coreStatus */) public coreStatuses;

    /** Assigned core for a given chainId */
    mapping(bytes20 /* chainId */ => address /* core */) public assignments;

    /** Precommitts from cores for metablockchains. */
    mapping(address /* core */ => Precommit) public precommits;

    /** Precommits under consideration of committees. */
    mapping(bytes32 /* precommit */ => CommitteeI /* committee */) public proposals;

    /** Precommits under consideration of committees. */
    mapping(address /* committee */ => bytes32 /* commit */) public decisions;

    /** Linked-list of committees */
    mapping(address => address) public committees;

    // NOTE: consider either storing a linked list; or getting rid of it
    /** Assigned anchor for a given chainId */
    mapping(bytes20 => address) public anchors;

    /** Reputation contract for validators */
    ReputationI public reputation;

    /** Axiom contract address */
    AxiomI public axiom;


    /* Modifiers */

    modifier onlyValidator()
    {
        require(
            reputation.isActive(msg.sender),
            "Validator must be active in the reputation contract."
        );

        _;
    }

    modifier onlyCore()
    {
        require(
            isCore(msg.sender),
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
        // TODO: create domain separator

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
            reputation.isActive(_validator),
            "Validator is not active."
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
     *          - chain id should not be 0
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
     * @param _chainId Chain id.
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
        bytes20 _chainId,
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
        address core = assignments[_chainId];
        require(
            isCore(core),
            "There is no core for the specified chain id."
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
        anchorStateRoot(_chainId, _rlpBlockHeader);

        // Open a new metablock.
        CoreI(core).openMetablock(
            _dynasty,
            _accumulatedGas,
            _source,
            _sourceBlockHeight,
            gasTargetDelta
        );
    }

    /**
     * @notice Validator joins the core, when core status is opened or
     *         precommitted. This is called by validator address.
     *
     * @dev Function requires:
     *          - core status should be opened or precommitted.
     *
     * @param _chainId Chain id that validator wants to join.
     * @param _core Core address that validator wants to join.
     * @param _withdrawalAddress A withdrawal address of newly joined validator.
     */
    function join(
        bytes20 _chainId,
        address _core,
        address _withdrawalAddress
    )
        external
    {
        // Validate the join params.
        validateJoinParams(_chainId, _core, _withdrawalAddress);

        // Specified core must have open or precommitted status.
        CoreStatus status = coreStatuses[_core];
        require(
            status == CoreStatus.opened || status == CoreStatus.precommitted,
            "Core status is not opened or precommitted."
        );

        // Join in reputation contract.
        reputation.join(msg.sender, _withdrawalAddress);

        // Join in core contract.
        CoreI(_core).join(msg.sender);
    }

    /**
     * @notice Validator joins the core, when core status is creation.
     *         This is called by validator address.
     *
     * @dev Function requires:
     *          - core should be in an active state.
     *
     * @param _chainId Chain id that validator wants to join.
     * @param _core Core address that validator wants to join.
     * @param _withdrawalAddress A withdrawal address of newly joined validator.
     */

    function joinDuringCreation(
        bytes20 _chainId,
        address _core,
        address _withdrawalAddress
    )
        external
    {
        // Validate the join params.
        validateJoinParams(_chainId, _core, _withdrawalAddress);

        // Specified core must have creation status.
        require(
            isCore(_core),
            "Core must be in an active state."
        );

        // Join in reputation contract.
        reputation.join(msg.sender, _withdrawalAddress);

        // Join in core contract.
        CoreI(_core).joinDuringCreation(msg.sender);
    }

    /**
     * @notice Validator logs out. This is called by validator address.
     *
     * @dev Function requires:
     *          - chain id should not be 0.
     *          - core address should not be 0.
     *          - core should be assigned for the specified chain id.
     *          - core for the specified chain id should exist.
     *
     * @param _chainId Chain id that validator wants to logout.
     * @param _core Core address that validator wants to logout.
     */
    function logout(
        bytes20 _chainId,
        address _core
    )
        external
    {
        require(
            _chainId != bytes20(0),
            "Chain id is 0."
        );

        require(
            _core != address(0),
            "Core address is 0."
        );

        require(
            assignments[_chainId] == _core,
            "Core is not assigned for the specified chain id."
        );

        require(
            isCore(_core),
            "There is no core for the specified chain id."
        );

        CoreI(_core).logout(msg.sender);
        reputation.logout(msg.sender);
    }

    /**
     * @notice Creates a new meta chain given an achor.
     *         This can be called only by axiom.
     *
     * @dev Function requires:
     *          - msg.sender should be axiom contract.
     *          - core is not assigned to metachain.
     *
     * @param _anchor anchor of the new meta-chain.
     * @param _epochLength Epoch length for new meta-chain.
     * @param _rootBlockHash root block hash.
     * @param _rootBlockHeight root block height.
     */
    function newMetaChain(
        address _anchor,
        uint256 _epochLength,
        bytes32 _rootBlockHash,
        uint256 _rootBlockHeight
    )
        external
        onlyAxiom
    {
        bytes20 chainId = bytes20(_anchor);

        require(
            assignments[chainId] == address(0),
            "A core is already assigned to this metachain."
        );

        address core = newCore(
            chainId,
            _epochLength,
            uint256(0), // metablock height
            bytes32(0), // parent hash
            gasTargetDelta, // gas target
            uint256(0), // dynasty
            uint256(0), // accumulated gas
            _rootBlockHash,
            _rootBlockHeight
        );

        assignments[chainId] = core;
        anchors[chainId] = _anchor;
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


    /* Internal functions */

    /**
     * @notice Check if the core address is active.
     * @param _core Core contract address.
     * Returns true if the specified address is a core.
     */
    function isCore(address _core)
        internal
        view
        returns (bool)
    {
        CoreStatus status = coreStatuses[_core];
        return status >= CoreStatus.creation;
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

        require(
            decision == precommit,
            "Committee has not agreed with core's precommit."
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
     * @notice Anchor a new state root for specified chain id.

     * @dev Function requires:
     *          - anchor for specified chain id should exist.
     *
     * @param _chainId Chain id.
     * @param _rlpBlockHeader RLP encoded block header
     */
    function anchorStateRoot(
        bytes20 _chainId,
        bytes memory _rlpBlockHeader
    )
        private
    {
        address anchorAddress = anchors[_chainId];
        require(
            anchorAddress != address(0),
            "There is no anchor for the specified chain id."
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
     * @param _chainId Chain id for which the core should be deployed.
     * @param _epochLength Epoch length for new core.
     * @param _height Kernel height.
     * @param _parent Kernel parent hash.
     * @param _gasTarget Gas target to close the meta block.
     * @param _dynasty Committed dynasty number.
     * @param _accumulatedGas Accumulated gas.
     * @param _source Source block hash
     * @param _sourceBlockHeight Source block height.
     * returns Deployed core contract address.
     */
    function newCore(
        bytes20 _chainId,
        uint256 _epochLength,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _source,
        uint256 _sourceBlockHeight
    )
        private
        returns (address core_)
    {
        bytes memory coreSetupData = abi.encodeWithSelector(
            CORE_SETUP_CALLPREFIX,
            address(this),
            _chainId,
            _epochLength,
            minValidators,
            joinLimit,
            address(reputation),
            _height,
            _parent,
            _gasTarget,
            _dynasty,
            _accumulatedGas,
            _source,
            _sourceBlockHeight
        );

        core_ = axiom.newCore(
            coreSetupData
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

    /**
     * @notice Validate the params for joining the core.
     *
     * @dev Function requires:
     *          - chain id should not be 0.
     *          - core address should not be 0.
     *          - core should be assigned for the specified chain id.
     *          - withdrawal address can't be 0.
     *
     * @param _chainId Chain id.
     * @param _core Core contract address.
     * @param _withdrawalAddress Withdrawal address.
     */
    function validateJoinParams(
        bytes20 _chainId,
        address _core,
        address _withdrawalAddress
    )
        private
        view
    {
        require(
            _chainId != bytes20(0),
            "Chain id is 0."
        );

        require(
            _core != address(0),
            "Core address is 0."
        );

        require(
            assignments[_chainId] == _core,
            "Core is not assigned for the specified chain id."
        );

        require(
            _withdrawalAddress != address(0),
            "Withdrawal address is 0."
        );
    }
}

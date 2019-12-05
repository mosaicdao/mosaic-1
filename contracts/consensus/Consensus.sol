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

contract Consensus is MasterCopyNonUpgradable, CoreLifetimeEnum, ConsensusI {

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
    mapping(address /* core */ => CoreLifetime /* coreLifetime */) public coreLifetime;

    /** Assigned core for a given chainId */
    mapping(bytes20 /* chainId */ => address /* core */) public assignments;

    /** Precommitted proposals from core for a metablockchain */
    mapping(address /* core */ => Precommit) public precommits;

    /** Proposals under consideration of a committee */
    mapping(bytes32 /* proposal */ => CommitteeI /* committee */) public proposals;

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
            isCoreActive(msg.sender),
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
     * @notice Register a proposal for commit. This can be called only by the valid
     *         core address.
     *
     * @dev Function requires:
     *          - msg.sender should be valid core address in creation state.
     *          - proposal should not be null.
     *          - precommit of same core should not exist.
     *
     * @param _proposal Precommit proposal.
     */
    function registerPrecommit(bytes32 _proposal)
        external
        onlyCore
    {
        require(
            _proposal != bytes32(0),
            "Proposal must not be null."
        );
        // TODO: we can additional
        Precommit storage precommit = precommits[msg.sender];
        require(
            precommit.proposal == bytes32(0),
            "There already exists a precommit of the core."
        );

        // On first precommit by a core, CoreLifetime state will change to active.
        if(coreLifetime[msg.sender] == CoreLifetime.genesis) {
            coreLifetime[msg.sender] = CoreLifetime.active;
        }

        precommit.proposal = _proposal;
        precommit.committeeFormationBlockHeight = block.number.add(uint256(COMMITTEE_FORMATION_DELAY));
    }

    /**
     * @notice Form a new committee to validate the precommit proposal.
     *
     * @dev Function assumes block number is greater than 256 plus committee
     *      formation length.
     *
     * @dev Function requires:
     *          - precommitment of the core to a proposal doesn't exist.
     *          - block height must be higher than set committee formation
     *            height.
     *          - committee formation blocksegment length must be in 256 most
     *            recent blocks.
     *
     * @param _core Core contract address.
     */
    function formCommittee(address _core)
        external
    {
        require(
            coreLifetime[_core] == CoreLifetime.active,
            "Core lifetime status must be active"
        );

        Precommit storage precommit = precommits[_core];
        require(
            precommit.proposal != bytes32(0),
            "There does not exist a precommitment of the core to a proposal."
        );

        require(
            block.number > precommit.committeeFormationBlockHeight,
            "Block height must be higher than set committee formation height."
        );

        require(
            block.number
                .sub(uint256(COMMITTEE_FORMATION_LENGTH))
                .sub(uint256(256)) < precommit.committeeFormationBlockHeight,
            "Committee formation blocksegment length must be in 256 most recent blocks."
        );

        uint256 segmentHeight = precommit.committeeFormationBlockHeight;
        bytes32[] memory seedGenerator = new bytes32[](uint256(COMMITTEE_FORMATION_LENGTH));
        for (uint8 i = 0; i < COMMITTEE_FORMATION_LENGTH; i++) {
            seedGenerator[i] = blockhash(segmentHeight);
            segmentHeight = segmentHeight.sub(1);
        }

        bytes32 seed = keccak256(
            abi.encodePacked(seedGenerator)
        );

        startCommittee(seed, precommit.proposal);
    }

    /**
     * @notice Enter a validator into the committee.
     *
     * @dev Function requires:
     *          - committee address should be present.
     *          - validator should be active.
     *          - validator successfully enter a committee.
     *
     * @param _committeeAddress Committee address that validator wants to enter.
     * @param _validator Validator address to enter.
     * @param _furtherMember Validator address that is further member compared to `_validator` address
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
        require(
            committee.enterCommittee(_validator, _furtherMember),
            "Failed to enter committee."
        );
    }

    /**
     * @notice Commit a proposal. This verifies the committee lock of the
     *         proposal, anchors the state root and opens a new matablock.
     *
     * @dev Function requires:
     *          - chain id should not be 0.
     *          - source block hash should not be 0.
     *          - target block hash should not be 0.
     *          - target block height should be greater than source block
     *            height.
     *          - block header should match with vote message source.
     *          - origin observation should not be 0.
     *          - core for the specified chain id should exist.
     *          - precommit for the specified core doesn't exist.
     *          - provided kernel hash should be equal to open kernel hash.
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
    function commit(
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
            _chainId != bytes20(0),
            "Chain id is 0."
        );

        require(
            _source != bytes32(0),
            "Source is 0."
        );

        require(
            _target != bytes32(0),
            "Target is 0."
        );

        require(
            _targetBlockHeight > _sourceBlockHeight,
            "Target block height is less than or equal to source block height."
        );

        require(
            _source == keccak256(_rlpBlockHeader),
            "Block header does not match with vote message source."
        );

        require(
            _originObservation != bytes32(0),
            "Origin observation is 0."
        );

        // Make sure that core is valid for given chain id.
        address core = assignments[_chainId];
        require(
            coreLifetime[core] == CoreLifetime.active,
            "Core lifetime status must be active"
        );

        /*
         * @dev: Please check the following carefully.
         * Here we assume that the given input parameters are correct. The
         * actual validation of input parameter will happen in Core::openMetablock.
         * Here we will make sure that precommit in consensus and core contract
         * are same. Core::openMetablock will verify that commit formed by input
         * params is equal to precommit.
         */
        bytes32 precommitProposal = precommits[core].proposal;

        // Make sure that precommitProposal exists.
        require(
            precommitProposal != bytes32(0),
            "There is no precommit for the specified core."
        );

        // Delete the precommit. This will avoid any re-entrancy with same params.
        delete precommits[core];

        // Verify kernel hash.
        require(
            _kernelHash == CoreI(core).openKernelHash(),
            "Provided kernel hash must be equal to open kernel hash."
        );

        // Verify commit proposal.
        verifyCommitProposal(core, precommitProposal);

        // Verify committee lock.
        verifyCommitteeLock(precommitProposal, _committeeLock);

        // Anchor state root.
        anchorStateRoot(_chainId, _rlpBlockHeader);

        // Open a new metablock.
        CoreI(core).openMetablock(
            _originObservation,
            _dynasty,
            _accumulatedGas,
            _committeeLock,
            _source,
            _target,
            _sourceBlockHeight,
            _targetBlockHeight,
            gasTargetDelta
        );
    }

    /**
     * @notice Validator joins the core, when core lifetime status is
     *         is active. This is called by validator address.
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

        require(
            isCoreActive(_core),
            "Core lifetime status must be genesis or active."
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

        // Specified core must have genesis lifetime status.
        require(
            coreLifetime[_core] == CoreLifetime.creation,
            "Core lifetime status must be creation."
        );

        // Join in reputation contract.
        reputation.join(msg.sender, _withdrawalAddress);

        // Join in core contract.
        uint256 coreValidatorCount = CoreI(_core).joinDuringCreation(msg.sender);

        if(coreValidatorCount == CoreI(_core).minimumValidatorCount()) {
            coreLifetime[_core] = CoreLifetime.genesis;
        }
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
            isCoreActive(_core),
            "Core lifetime status must be genesis or active."
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
     * @notice Check if the core lifetime state is genesis or active.
     * @param _core Core contract address.
     * Returns true if the specified address is a core.
     */
    function isCoreActive(address _core)
        internal
        view
        returns (bool)
    {
        CoreLifetime lifeTimeStatus = coreLifetime[_core];
        return lifeTimeStatus == CoreLifetime.genesis ||
            lifeTimeStatus == CoreLifetime.active;
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
     * @notice Verify if the given commit proposal is same as that precommit in
     *         core contract.
     *
     * @dev Function requires:
     *          - proposal should be precommitted.
     *
     * @param _core Core contract address.
     * @param _commitProposal Commit proposal.
     */
    function verifyCommitProposal(
        address _core,
        bytes32 _commitProposal
    )
        private
    {
        bytes32 precommitProposal = CoreI(_core).precommit();
        require(
            precommitProposal == _commitProposal,
            "Proposal is not precommitted."
        );
    }

    /**
     * @notice Verify if the committee lock given in the commit proposal
     *         matches the committee decision.
     *
     * @dev Function requires:
     *          - committee should match to the specified vote message.
     *          - committee proposal is decided.
     *          - committee decision should match with committee lock.
     *
     * @param _commitProposal Proposal to commit.
     * @param _committeeLock Committee lock specified in the proposal.
     */
    function verifyCommitteeLock(
        bytes32 _commitProposal,
        bytes32 _committeeLock
    )
        private
        view
    {
        CommitteeI committee = proposals[_commitProposal];

        require(
            committee != CommitteeI(0),
            "There is no committee matching to the specified vote message."
        );

        require(
            committee.committeeDecision() != bytes32(0),
            "Committee has not decided on the proposal."
        );

        require(
            _committeeLock == keccak256(
                abi.encode(committee.committeeDecision())
            ),
            "Committee decision does not match with committee lock."
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
        coreLifetime[core_] = CoreLifetime.creation;
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

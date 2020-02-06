pragma solidity >=0.5.0 <0.6.0;

// Copyright 2020 OpenST Ltd.
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

import "../anchor/ObserverI.sol";
import "../block/BlockHeader.sol";
import "../consensus/GenesisCoconsensus.sol";
import "../consensus-gateway/ConsensusCogatewayI.sol";
import "../protocore/ProtocoreI.sol";
import "../protocore/SelfProtocoreI.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../reputation/CoreputationI.sol";
import "../version/MosaicVersion.sol";
import "../vote-message/VoteMessage.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title Coconsensus contract - This mirrors the consensus contract on
 *        the auxiliary chain.
 */
contract Coconsensus is
    MasterCopyNonUpgradable,
    GenesisCoconsensus,
    VoteMessage,
    MosaicVersion
{

    /* Usings */

    using SafeMath for uint256;


    /* Enums */

    /** Enum for status of committed checkpoint. */
    enum CheckpointCommitStatus {
        Undefined,
        Finalized,
        Committed
    }


    /* Structs */

    /** Struct to track dynasty and checkpoint commit status of a block. */
    struct Block {
        bytes32 blockHash;
        CheckpointCommitStatus commitStatus;
        uint256 statusDynasty;
    }


    /* Constants */

    /** EIP-712 type hash for Kernel. */
    bytes32 public constant KERNEL_TYPEHASH = keccak256(
        "Kernel(uint256 height,bytes32 parent,address[] updatedValidators,uint256[] updatedReputation,uint256 gasTarget,uint256 gasPrice)"
    );

    /**
     * Sentinel pointer for marking the ending of circular,
     * linked-list of genesis metachain ids.
     */
    bytes32 public constant SENTINEL_METACHAIN_ID = bytes32(
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    );


    /* Storage */

    /** Metachain id of the origin chain. */
    bytes32 public originMetachainId;

    /** Metachain id of the auxiliary chain (self). */
    bytes32 public selfMetachainId;

    /**
     * Relative self dynasty of self protocore. This will be incremented when the
     * self protocore contract will call `finalizeCheckpoint`
     */
    uint256 public relativeSelfDynasty;

    /** Mapping to track the finalised blocks of each metachain. */
    mapping (bytes32 /* metachainId */ =>
        mapping(uint256 /* blocknumber */ => Block)
    ) public blockchains;

    /**
     * Mapping of metachain id to latest block number(tip) stored
     * in blockchains.
     */
    mapping (bytes32 /* metachainId */ => uint256 /* blocknumber */) public blockTips;

    /** Mapping of metachain id to the protocore contract address. */
    mapping (bytes32 /* metachainId */ => ProtocoreI) public protocores;

    /** Mapping of metachain id to the observers contract address. */
    mapping (bytes32 /* metachainId */ => ObserverI) public observers;

    /** Mapping of metachain id to the domain separators. */
    mapping (bytes32 /* metachainId */ => bytes32 /* domain separator */) public domainSeparators;

    /** Coreputation contract address. */
    address private COREPUTATION = address(
        0x0000000000000000000000000000000000004D01
    );

    /** Consensus cogateway contract address. */
    address private CONSENSUS_COGATEWAY = address(
        0x0000000000000000000000000000000000004d02
    );


    /* Modifiers */

    modifier onlyRunningProtocore(bytes32 _metachainId)
    {
        require(
            msg.sender == address(protocores[_metachainId]),
            "Protocore is not available for the given metachain id."
        );

        _;
    }


    /* Special Functions */

    /**
     * @notice Setup function does the initialization of all the mosaic
     *         contracts on the auxiliary chain.
     *
     * @dev This function can be called only once.
     */
    function setup() public {

        require(
            selfMetachainId == bytes32(0),
            "Coconsensus contract is already initialized."
        );

        originMetachainId = genesisOriginMetachainId;

        selfMetachainId = genesisSelfMetachainId;

        bytes32 currentMetachainId = genesisMetachainIds[SENTINEL_METACHAIN_ID];

        // Loop through the genesis metachainId link list.
        while (currentMetachainId != SENTINEL_METACHAIN_ID) {

            // Setup protocore contract for the given metachain id.
            setupProtocore(currentMetachainId);

            // Setup observer contract for the given metachain id.
            setupObserver(currentMetachainId);

            // Traverse to next metachain id from the link list mapping.
            currentMetachainId = genesisMetachainIds[currentMetachainId];
        }
    }


    /* External Functions */

    /**
     * @notice Updates the validator set and its reputations with opening of
     *         a new metablock.
     *
     * @param _metachainId Metachain Id.
     * @param _kernelHeight New kernel height
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for the metablock
     * @param _transitionHash Transition hash.
     * @param _source Blockhash of source checkpoint.
     * @param _target Blockhash of target checkpoint.
     * @param _sourceBlockNumber Block number of source checkpoint.
     * @param _targetBlockNumber Block number af target checkpoint.
     *
     * \pre `_metachainId` is self metachain id.
     * \pre `_source` is not 0.
     * \pre `_target` is not 0.
     * \pre `_sourceBlockNumber` is a checkpoint.
     * \pre `_targetBlockNumber` is a checkpoint.
     * \pre `_targetBlockNumber` is greater than `_sourceBlockNumber`.
     * \pre Source checkpoint is finalized.
     * \pre Open kernel hash exists in `ConsensusCogateway` contract for the
     *      given `_kernelHeight`.
     *
     * \post Updates the validator set in self protocore.
     * \post Updates the reputation of validators.
     * \post Opens a new metablock in self protocore.
     */
    function commitCheckpoint(
        bytes32 _metachainId,
        uint256 _kernelHeight,
        address[] calldata _updatedValidators,
        uint256[] calldata _updatedReputation,
        uint256 _gasTarget,
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        external
    {
        require(
            _metachainId == selfMetachainId,
            "Metachain id must be self metachain id."
        );

        // Change the status of source block to committed.
        commitCheckpointInternal(_metachainId, _sourceBlockNumber);

        // Assert that the kernel hash is opened.
        bytes32 openKernelHash = assertOpenKernel(
            _kernelHeight,
            _updatedValidators,
            _updatedReputation,
            _gasTarget,
            _transitionHash,
            _source,
            _target,
            _sourceBlockNumber,
            _targetBlockNumber
        );

        ProtocoreI protocore = protocores[_metachainId];

        /*
         * Update reputation of validators and update the validator set in self
         * protocore contract.
         */
        updateValidatorSet(
            address(protocore),
            _kernelHeight,
            _updatedValidators,
            _updatedReputation
        );

        // Open new kernel on self protocore contract.
        protocore.openKernel(
            _kernelHeight,
            openKernelHash
        );
    }

    /**
     * @notice finaliseCheckpoint() function finalizes a checkpoint at
     *         a metachain.
     *
     * @param _metachainId A metachain id to finalize a checkpoint.
     * @param _blockNumber A block number of a checkpoint.
     * @param _blockHash A block hash of a checkpoint.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_blockHash` is not 0.
     * \pre `msg.sender` should be the protocore contract.
     * \pre `_blockNumber` must be multiple of epoch length.
     * \pre `_blockNumber` must be greater than the last finalized block number.
     *
     * \post Increment the `relativeSelfDynasty` storage value by one if the
     *       `msg.sender` is self protocore contract address.
     * \post Adds a new `Block` in the `blockchains` mapping.
     * \post Updates the `blockTips` mapping with provided `_blockNumber`.
     */
    function finaliseCheckpoint(
        bytes32 _metachainId,
        uint256 _blockNumber,
        bytes32 _blockHash
    )
        external
        onlyRunningProtocore(_metachainId)
    {
        // Check if the metachain id is not null.
        require(
            _metachainId != bytes32(0),
            "Metachain id must not be null."
        );
        // Check if the blockhash is not null.
        require(
            _blockHash != bytes32(0),
            "Blockhash must not be null."
        );

        /*
         * Assert that the new block number is greater than the last
         * finalised block number.
         */
        uint256 lastFinalisedBlockNumber = blockTips[_metachainId];
        assert(_blockNumber > lastFinalisedBlockNumber);

        /*
         * If the `_metachainId` is `selfMetachainId`, increment the
         * `relativeSelfDynasty` by one.
         */
        if(_metachainId == selfMetachainId) {
            relativeSelfDynasty = relativeSelfDynasty.add(1);
        }

        // Store the finalised block in the mapping.
        Block storage finalisedBlock = blockchains[_metachainId][_blockNumber];
        finalisedBlock.blockHash = _blockHash;
        finalisedBlock.commitStatus = CheckpointCommitStatus.Finalized;
        finalisedBlock.statusDynasty = relativeSelfDynasty;

        // Store the tip.
        blockTips[_metachainId] = _blockNumber;
    }

    /**
     * @notice Observes the given block by anchoring its state root into the
     *         corresponding observer.
     *
     * @param _metachainId Metachain id.
     * @param _rlpBlockHeader RLP encoded block header.
     *
     * \pre `_metachainId` is not 0.
     * \pre `_rlpBlockHeader` is not 0.
     * \pre `_metachainId` is not `selfMetachainId`.
     * \pre A block must exist in `blockchains` storage for the given
     *      `_metachainid` and block number from the decoded `_rlpBlockHeader`.
     * \pre The commit status of the block must be at least `Finalized`.
     * \pre The status dynasty of the block is less than `relativeSelfDynasty`.
     *
     * \post Anchors the state root in the observer contract.
     */
    function observeBlock(
        bytes32 _metachainId,
        bytes calldata _rlpBlockHeader
    )
        external
    {
        require(
            _metachainId != bytes32(0),
            "Metachain id must not be null."
        );

        require(
            _rlpBlockHeader.length != 0,
            "RLP block header must not be null."
        );

        require(
            _metachainId != selfMetachainId,
            "Metachain id must not be self metachain id."
        );

        // Decode the rlp encoded block header.
        BlockHeader.Header memory blockHeader = BlockHeader.decodeHeader(_rlpBlockHeader);

        Block memory finalizedBlock = blockchains[_metachainId][blockHeader.height];

        require(
            finalizedBlock.blockHash == blockHeader.blockHash,
            "Provided block header is not valid."
        );

        require(
            finalizedBlock.commitStatus >= CheckpointCommitStatus.Finalized,
            "Block must be at least finalized."
        );

        require(
            relativeSelfDynasty > finalizedBlock.statusDynasty,
            "Relative self dynasty must be greater than the status dynasty."
        );

        // Get the observer contract.
        ObserverI observer = observers[_metachainId];

        // Anchor the state root.
        observer.anchorStateRoot(blockHeader.height, blockHeader.stateRoot);
    }


    /* Internal Functions */

    /** @notice Get the coreputation contract address. */
    function getCoreputation()
        internal
        view
        returns (CoreputationI)
    {
        return CoreputationI(COREPUTATION);
    }

    /** @notice Get the consensus cogateway contract address. */
    function getConsensusCogateway()
        internal
        view
        returns (ConsensusCogatewayI)
    {
        return ConsensusCogatewayI(CONSENSUS_COGATEWAY);
    }

    /**
     * @notice Takes the parameters of a kernel object and returns the
     *         typed hash of it.
     *
     * @param _domainSeparator Domain separator.
     * @param _height The height of metablock.
     * @param _parent The hash of this metablock's parent.
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock.
     *
     * @return hash_ The hash of kernel.
     */
    function hashKernel(
        bytes32 _domainSeparator,
        uint256 _height,
        bytes32 _parent,
        address[] memory _updatedValidators,
        uint256[] memory _updatedReputation,
        uint256 _gasTarget
    )
        internal
        pure
        returns (bytes32 hash_)
    {
        bytes32 typedKernelHash = keccak256(
            abi.encode(
                KERNEL_TYPEHASH,
                _height,
                _parent,
                _updatedValidators,
                _updatedReputation,
                _gasTarget
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                _domainSeparator,
                typedKernelHash
            )
        );
    }


    /* Private Functions */

    /**
     * @notice Do the initial setup of protocore contract and initialize the
     *         storage of coconsensus contract.
     *
     * @param _metachainId Metachain id.
     *
     * \pre Protocore contract must exist for the given metachain id in
     *      the genesisProtocores storage variable.
     *
     * \post Adds newly setup protocore's address into protocores storage variable.
     * \post Adds newly setup protocore's domain separator into domainSeparators
     *       storage variable.
     * \post Adds a new Block into blockchain storage variable.
     * \post Updates blockTips storage variable with the latest finalized
     *       checkpoint's block number of the newly setup protocore.
     */
    function setupProtocore(bytes32 _metachainId) private {

        // Get the protocore contract address from the genesis storage.
        address protocoreAddress = genesisProtocores[_metachainId];

        require(
            protocoreAddress != address(0),
            "Protocore address must not be null."
        );

        ProtocoreI protocore = ProtocoreI(protocoreAddress);

        // Store the protocore address in protocores mapping.
        protocores[_metachainId] = protocore;

        // Setup protocore.
        ( bytes32 blockHash, uint256 blockNumber ) = protocore.setup();

        // Get the domain separator and store it in domainSeparators mapping.
        domainSeparators[_metachainId] = protocore.domainSeparator();

        // Store the block informations in blockchains mapping.
        blockchains[_metachainId][blockNumber] = Block(
            blockHash,
            CheckpointCommitStatus.Finalized,
            relativeSelfDynasty
        );

        // Store the blocknumber as tip.
        blockTips[_metachainId] = blockNumber;
    }

    /**
     * @notice Do the initial setup of observer contract and initialize the
     *         storage of coconsensus contract.
     *
     * @param _metachainId Metachain id
     *
     * \post If observer contract address exists for the given metachain id
     *       then it adds newly setup observer's address into observers
     *       storage variable, otherwise does nothing.
     */
    function setupObserver(bytes32 _metachainId) private {

        // Get the observer contract address from the genesis storage.
        address observerAddress = genesisObservers[_metachainId];
        if(observerAddress != address(0)) {
            ObserverI observer = ObserverI(observerAddress);

            // Update the observers mapping.
            observers[_metachainId] = observer;

            // Call the setup function.
            observer.setup();
        }
    }

    /**
     * @notice Assert the opening of kernel in consensus cogateway.
     *
     * @param _kernelHeight New kernel height
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock
     * @param _transitionHash Transition hash.
     * @param _source Blockhash of source checkpoint.
     * @param _target Blockhash of target checkpoint.
     * @param _sourceBlockNumber Block number of source checkpoint.
     * @param _targetBlockNumber Block number af target checkpoint.
     *
     * \pre Kernel hash generated from given input parameters is equal to the
     *      kernel hash form consensus cogateway contract for the given
     *      `_kernelHeight`.
     *
     * \post return the kernel hash.
     */
    function assertOpenKernel(
        uint256 _kernelHeight,
        address[] memory _updatedValidators,
        uint256[] memory _updatedReputation,
        uint256 _gasTarget,
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockNumber,
        uint256 _targetBlockNumber
    )
        private
        returns (bytes32 kernelHash_)
    {
        // Get the domain separator for the protocore.
        bytes32 domainSeparator = domainSeparators[selfMetachainId];

        /*
         * Get the metablock hash from the input parameters. This will be the
         * parent hash for the new kernel.
         */
        bytes32 metablockHash = VoteMessage.hashVoteMessage(
            domainSeparator,
            _transitionHash,
            _source,
            _target,
            _sourceBlockNumber,
            _targetBlockNumber
        );

        // Generate the kernel hash from the input params.
        kernelHash_ = hashKernel(
            domainSeparator,
            _kernelHeight,
            metablockHash,
            _updatedValidators,
            _updatedReputation,
            _gasTarget
        );

        ConsensusCogatewayI consensusCogateway = getConsensusCogateway();

        // Get the open kernel hash from the consensus cogateway contract.
        bytes32 openKernelHash = consensusCogateway.getKernelHash(_kernelHeight);

        require(
            kernelHash_ == openKernelHash,
            "Generated kernel hash is not equal to open kernel hash."
        );
    }

    /**
     * @notice Change the checkpoint commit status of the block to `Committed`.
     *
     * @param _metachainId Metachain id.
     * @param _blockNumber block number.
     *
     * \pre The commit checkpoint status of Block at the given `_blockNumber`
     *      is `Finalized`.
     *
     * \post The checkpoint commit status of the Block at the given
     *       `_blockNumber` is changed to `Committed`.
     */
    function commitCheckpointInternal(
        bytes32 _metachainId,
        uint256 _blockNumber
    )
        private
    {
        Block storage finalizedBlock = blockchains[_metachainId][_blockNumber];
        require(
            finalizedBlock.commitStatus == CheckpointCommitStatus.Finalized,
            "Source checkpoint must be finalized."
        );
        finalizedBlock.commitStatus = CheckpointCommitStatus.Committed;
    }

    /**
     * @notice Add or update the reputation of the validators and also add or
     *         update the validator set in the self protocore contract.
     *
     * @param _protocore Self protocore contract address.
     * @param _kernelHeight Open kernel height.
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     *
     * \post Adds or updates the reputation of validators in `Coreputation` contract.
     * \post Adds or updates the validator set in `SelfProtocore` contract.
     */
    function updateValidatorSet(
        address _protocore,
        uint256 _kernelHeight,
        address[] memory _updatedValidators,
        uint256[] memory _updatedReputation
    )
        private
    {
        SelfProtocoreI selfProtocore = SelfProtocoreI(_protocore);
        CoreputationI coreputation = getCoreputation();

        for (uint256 i = 0; i < _updatedValidators.length; i = i.add(1)) {
            address validator = _updatedValidators[i];
            uint256 reputation = _updatedReputation[i];
            coreputation.upsertValidator(validator, reputation);

            selfProtocore.upsertValidator(
                validator,
                _kernelHeight,
                reputation
            );
        }
    }
}

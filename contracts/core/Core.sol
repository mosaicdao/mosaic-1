pragma solidity ^0.5.0;

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

import "../version/MosaicVersion.sol";
import "../consensus/ConsensusModule.sol";
import "../reputation/ReputationI.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Core is ConsensusModule, MosaicVersion {

    using SafeMath for uint256;

    /* Enum and structs */

    /** The kernel of a meta-block header */
    struct Kernel {
        /** The height of the metablock in the chain */
        uint256 height;
        /** Hash of the metablock's parent */
        bytes32 parent;
        /** Added validators */
        address[] updatedValidators;
        /** Removed validators */
        uint256[] updatedReputation;
        /** Gas target to close the metablock */
        uint256 gasTarget;
        /** Gas price fixed for this metablock */
        uint256 gasPrice;
    }

    struct Transition {
        /** Kernel Hash */
        bytes32 KernelHash;
        /** Observation of the origin chain */
        bytes32 originObservation;
        /** Dynasty number of the metablockchain */
        uint256 dynasty;
        /** Accumulated gas on the metablockchain */
        uint256 accumulatedGas;
        /** Committee lock is the hash of the accumulated transaction root */
        bytes32 committeeLock;
    }

    struct VoteMessage {
        /** Transition hash */
        bytes32 transitionHash;
        /** Source block hash */
        bytes32 source;
        /** Target block hash */
        bytes32 target;
        /** Source block height */
        uint256 sourceBlockHeight;
        /** Target block height */
        uint256 targetBlockHeight;
    }

    /* Storage */

    /** EIP-712 domain separator name for Core */
    string public constant DOMAIN_SEPARATOR_NAME = "Mosaic-Core";

    /** EIP-712 domain separator for Core */
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /** EIP-712 type hash for Kernel. */
    bytes32 public constant KERNEL_TYPEHASH = keccak256(
        "Kernel(uint256 height,bytes32 parent,address[] updatedValidators,uint256[] updatedReputation,uint256 gasTarget,uint256 gasPrice)"
    );

    /** EIP-712 type hash for a Transition. */
    bytes32 public constant TRANSITION_TYPEHASH = keccak256(
        "Transition(bytes32 kernelHash, bytes32 originObservation,uint256 dynasty,uint256 accumulatedGas,bytes32 committeeLock)"
    );

    /** EIP-712 type hash for a Vote Message */
    bytes32 public constant VOTE_MESSAGE_TYPEHASH = keccak256(
        "VoteMessage(bytes32 transitionHash,bytes32 source,bytes32 target,uint256 sourceBlockHeight,uint256 targetBlockHeight)"
    );

    /** Sentinel pointer for marking end of linked-list of validators */
    address public constant SENTINEL_VALIDATORS = address(0x1);

    /** Domain separator */
    bytes32 public domainSeparator;

    /** Chain Id of the meta-blockchain */
    uint256 public chainId;

    /** Validators assigned to this core */
    mapping(address => address) public validators;

    /** Reputation contract */
    ReputationI public reputation;

    /** Open kernel */
    Kernel public openKernel;

    /** Open kernel hash */
    bytes32 public openKernelHash;

    /** Closed transition object */
    Transition public closedTransition;

    /** Sealing vote message */
    VoteMessage public sealedVoteMessage;

    /** Proposals submitted for closing the open Kernel */
    mapping(bytes32 => VoteMessage) public propositions;

    /**  */

    /* External and public functions */

    constructor(
        uint256 _chainId,
        uint256 _height,
        bytes32 _parent,
        uint256 _gasTarget,
        uint256 _gasPrice,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _source,
        uint256 _sourceBlockHeight
    )
        ConsensusModule(msg.sender)
        public
    {
        domainSeparator = keccak256(
            abi.encode(
                DOMAIN_SEPARATOR_TYPEHASH,
                DOMAIN_SEPARATOR_NAME,
                DOMAIN_SEPARATOR_VERSION,
                _chainId,
                address(this)
            )
        );

        openKernel.height = _height;
        openKernel.parent = _parent;
        openKernel.gasTarget = _gasTarget;
        openKernel.gasPrice = _gasPrice;

        openKernelHash = hashKernel(
            openKernel.height,
            openKernel.parent,
            openKernel.updatedValidators,
            openKernel.updatedReputation,
            openKernel.gasTarget,
            openKernel.gasPrice
        );

        closedTransition.dynasty = _dynasty;
        closedTransition.accumulatedGas = _accumulatedGas;

        sealedVoteMessage.source = _source;
        sealedVoteMessage.sourceBlockHeight = _sourceBlockHeight;
    }

    /**
     * Propose transition object and vote message from seal
     * for the open kernel.
     */
    function proposeMetablock(
        bytes32 _kernelHash,
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock,
        bytes32 _source,
        bytes32 /* _target */,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        external
        view
    {
        require(_kernelHash == openKernelHash,
            "A metablock can only be proposed for the open Kernel in this core.");
        require(_originObservation != bytes32(0),
            "Origin observation cannot be null.");
        require(_dynasty > closedTransition.dynasty,
            "Dynasty must strictly increase.");
        require(_accumulatedGas > closedTransition.accumulatedGas,
            "Accumulated gas must strictly increase.");
        require(_committeeLock != bytes32(0),
            "Committee lock cannot be null.");
        require(_source != bytes32(0),
            "Source blockhash must not be null.");
        // note: is this necessary?
        require(_source != sealedVoteMessage.source,
            "Source blockhash cannot equal sealed source blockhash.");
        require(_sourceBlockHeight > sealedVoteMessage.sourceBlockHeight,
            "Source block height must strictly increase.");
        require(_targetBlockHeight == _sourceBlockHeight.add(1),
            "Target block height must equal source block height plus one.");

        
    }

    // function registerVote(

    // )

    function join(address _validator)
        external
        view
        onlyConsensus
    {

    }

    /* Internal and private functions */

    /**
     * insert validator in linked-list
     */
    function insertValidator(address _validator)
        internal
    {
        require(_validator != address(0),
            "Validator must not be null address.");
        require(_validator != SENTINEL_VALIDATORS,
            "Validator must not be Sentinel address.");
        require(validators[_validator] == address(0),
            "Validator must not already be part of this core.");

        validators[_validator] = validators[SENTINEL_VALIDATORS];
        validators[SENTINEL_VALIDATORS] = _validator;
    }

    /**
     * remove validator from linked-list
     */
    function removeValidator(address _validator, address _prevValidator)
        internal
    {
        require(_validator != address(0) &&
            _validator != SENTINEL_VALIDATORS,
            "Validator null or sentinel address cannot be removed.");
        require(_validator == validators[_prevValidator],
            "Invalid validator-pair provided to remove validator from core.");
        validators[_prevValidator] = validators[_validator];
        delete validators[_validator];
    }

    /**
     * @notice Takes the parameters of a kernel object and returns the
     *         typed hash of it.
     *
     * @param _height The height of meta-block.
     * @param _parent The hash of this block's parent.
     * @param _updatedValidators  The array of addresses of the updated validators.
     * @param _updatedReputation The array of reputation that corresponds to
     *                        the updated validators.
     * @param _gasTarget The gas target for this metablock
     * @param _gasPrice The gas price for this metablock
     *
     * @return hash_ The hash of kernel.
     */
    function hashKernel(
        uint256 _height,
        bytes32 _parent,
        address[] memory _updatedValidators,
        uint256[] memory _updatedReputation,
        uint256 _gasTarget,
        uint256 _gasPrice
    )
        internal
        view
        returns (bytes32 hash_)
    {
        bytes32 typedKernelHash = keccak256(
            abi.encode(
                KERNEL_TYPEHASH,
                _height,
                _parent,
                _updatedValidators,
                _updatedReputation,
                _gasTarget,
                _gasPrice
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedKernelHash
            )
        );
    }

   /**
     * @notice Takes the parameters of an transition object and returns the
     *         typed hash of it.
     *
     * @param _originObservation Observation of the origin chain.
     * @param _dynasty The dynasty number where the meta-block closes
     *                 on the auxiliary chain.
     * @param _accumulatedGas The total consumed gas on auxiliary within this
     *                        meta-block.
     * @param _committeeLock The committee lock that hashes the transaction
      *                      root on the auxiliary chain.
     * @return hash_ The hash of this transition object.
     */
    function hashTransition(
        bytes32 _originObservation,
        uint256 _dynasty,
        uint256 _accumulatedGas,
        bytes32 _committeeLock
    )
        internal
        view
        returns (bytes32 hash_)
    {
        bytes32 typedTransitionHash = keccak256(
            abi.encode(
                TRANSITION_TYPEHASH,
                openKernelHash,
                _originObservation,
                _dynasty,
                _accumulatedGas,
                _committeeLock
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedTransitionHash
            )
        );
    }

    function hashVoteMessage(
        bytes32 _transitionHash,
        bytes32 _source,
        bytes32 _target,
        uint256 _sourceBlockHeight,
        uint256 _targetBlockHeight
    )
        internal
        view
        returns (bytes32 hash_)
    {
        bytes32 typedVoteMessageHash = keccak256(
            abi.encode(
                VOTE_MESSAGE_TYPEHASH,
                _transitionHash,
                _source,
                _target,
                _sourceBlockHeight,
                _targetBlockHeight
            )
        );

        hash_ = keccak256(
            abi.encodePacked(
                byte(0x19),
                byte(0x01),
                domainSeparator,
                typedVoteMessageHash
            )
        );
    }
}
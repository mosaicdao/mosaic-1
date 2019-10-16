pragma solidity >=0.5.0 <0.6.0;

import "../proxies/Proxy.sol";
import "../proxies/ProxyFactory.sol";
import "../consensus/ConsensusI.sol";

contract Axiom {

    /* Constants */

    /** The callprefix of the Reputation::setup function. */
    bytes4 public constant REPUTATION_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(address,EIP20I,uint256,EIP20I,uint256,uint256,uint256,uint256)"
        )
    );

    /** The callprefix of the Consensus::setup function. */
    bytes4 public constant CONSENSUS_SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(uint256,address)"
        )
    );


    /* Modifiers */

    modifier onlyConsensus()
    {
        require(
            consensus == msg.sender,
            "Caller must be consensus address."
        );

        _;
    }

    modifier onlyTechGov()
    {
        require(
            techGov == msg.sender,
            "Caller must be techinal governance address."
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

    /** Consensus contract address */
    address public consensus;

    /** Reputation contract address */
    address public reputation;

    /* Special Member Functions */

    // TODO: add documentation.
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
            "Tech gov adress is 0."
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

    function setupConsensus(
        uint256 _committeeSize,
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
            consensus == address(0),
            "Consensus is already setup."
        );

        // Deploy the consensus proxy contract.
        consensus = new Proxy(consensusMasterCopy);


        bytes memory reputationSetupData = abi.encodeWithSelector(
            REPUTATION_SETUP_CALLPREFIX,
            consensus,
            _tokenRules,
            gnosisSafeProxy_,
            _sessionKeys,
            _sessionKeysSpendingLimits,
            _sessionKeysExpirationHeights
        );

        reputation = new ProxyFactory(
            reputationMasterCopy,
            reputationSetupData
        );


        bytes memory consensusSetupData = abi.encodeWithSelector(
            CONSENSUS_SETUP_CALLPREFIX,
            _committeeSize,
            reputation
        );

        callProxyData(consensus, consensusSetupData);

    }

    function newMetaChain(
        uint256 _epochLength,
        uint256 _gasTarget,
        bytes32 _source,
        uint256 _sourceBlockHeight,
        uint256 _remoteChainId,
        bytes32 _stateRoot,
        uint256 _maxStateRoots
    )
        external
        onlyTechGov
    {
        // New anchor.
        address anchor = new Anchor(
            _remoteChainId,
            _sourceBlockHeight,
            _stateRoot,
            _maxStateRoots,
            consenses
        );

        consensus.newMetaChain(
            bytes20(anchor),
            _epochLength,
            _gasTarget,
            _source,
            _sourceBlockHeight
        );
        
        // New core.
        // Link both
    }

    function deployProxyContract(
        address masterCopy,
        bytes memory data
    )
        external
        onlyConsensus
        returns (address deployedAddress_)
    {
        deployedAddress_ = new ProxyFactory(
            masterCopy,
            data
        );
    }


    /* Private Functions */

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

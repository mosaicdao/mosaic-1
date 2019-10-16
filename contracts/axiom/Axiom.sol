pragma solidity >=0.5.0 <0.6.0;

import "../proxies/Proxy.sol";
import "../proxies/ProxyFactory.sol";
import "../consensus/ConsensusI.sol";
import "../anchor/Anchor.sol"; // TODO: change this to factory
import "./AxiomI.sol";

contract Axiom is AxiomI{

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

    /** Reputation master copy contract address */
    address public reputationMasterCopy;

    /** Consensus contract address */
    address public consensus;

    /** Reputation contract address */
    address public reputation;

    /** ProxyFactory contract address */
    ProxyFactory public proxyFactory;
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

        proxyFactory = new ProxyFactory();
    }


    /* External functions */

    function setupConsensus(
        uint256 _committeeSize,
        uint256 _minCoreSize,
        uint256 _maxCoreSize,
        uint256 _gasTargetDelta,
        uint256 _coinbaseSplitPercentage,
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
        Proxy consensusProxy = new Proxy(consensusMasterCopy);

        consensus = address(consensusProxy);

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

        reputation = address(
            proxyFactory.createProxy(
                reputationMasterCopy,
                reputationSetupData
            )
        );


        bytes memory consensusSetupData = abi.encodeWithSelector(
            CONSENSUS_SETUP_CALLPREFIX,
            _committeeSize,
            _minCoreSize,
            _maxCoreSize,
            _gasTargetDelta,
            _coinbaseSplitPercentage,
            reputation
        );

        callProxyData(consensusProxy, consensusSetupData);

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
        Anchor anchor = new Anchor(
            _remoteChainId,
            _sourceBlockHeight,
            _stateRoot,
            _maxStateRoots,
            consensus
        );

        ConsensusI(consensus).newMetaChain(
            bytes20(address(anchor)),
            _epochLength,
            _gasTarget,
            _source,
            _sourceBlockHeight
        );
    }

    function deployProxyContract(
        address masterCopy,
        bytes calldata data
    )
        external
        onlyConsensus
        returns (address deployedAddress_)
    {
        Proxy proxyContract = proxyFactory.createProxy(
            masterCopy,
            data
        );
        deployedAddress_ = address(proxyContract);
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

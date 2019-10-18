pragma solidity >=0.5.0 <0.6.0;

import "../proxies/Proxy.sol";
import "../proxies/ProxyFactory.sol";
import "../consensus/ConsensusI.sol";
import "../anchor/Anchor.sol"; // TODO: change this to factory, when new anchor is implemented.
import "./AxiomI.sol";

contract Axiom is AxiomI {

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
    address public consensus;

    /** Reputation contract address */
    address public reputation;

    /** ProxyFactory contract address */
    ProxyFactory public proxyFactory;


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

        proxyFactory = new ProxyFactory();
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
     * @param _coinbaseSplitPercentage Coinbase split percentage.
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
            _minValidators,
            _joinLimit,
            _gasTargetDelta,
            _coinbaseSplitPercentage,
            reputation
        );

        callProxyData(consensusProxy, consensusSetupData);
    }

    /**
     * @notice Setup a new meta chain. Only technical governance address can
     *         call this function.
     * @param _epochLength Epoch length.
     * @param _source Source blockhash.
     * @param _sourceBlockHeight Source block height.
     * @param _remoteChainId The chain id of the chain that is tracked by this
     *                       anchor.
     * @param _stateRoot State root hash of given _sourceBlockHeight.
     * @param _maxStateRoots The max number of state roots to store in the
     *                       circular buffer.
     */
    function newMetaChain(
        uint256 _epochLength,
        bytes32 _source,
        uint256 _sourceBlockHeight,
        uint256 _remoteChainId,
        bytes32 _stateRoot,
        uint256 _maxStateRoots
    )
        external
        onlyTechGov
    {
        // Task: When new Anchor is implemented, use proxy pattern for deployment.
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
            _source,
            _sourceBlockHeight
        );
    }

    /**
     * @notice Deploy proxy contract. This can be called only by consensus
     *         contract.
     * @param _masterCopy Master copy contract address.
     * @param _data Setup function call data.
     * @return Deployed contract address.
     */
    function deployProxyContract(
        address _masterCopy,
        bytes calldata _data
    )
        external
        onlyConsensus
        returns (address deployedAddress_)
    {
        require(
            _masterCopy != address(0),
            'Master copy address is 0.'
        );

        Proxy proxyContract = proxyFactory.createProxy(
            _masterCopy,
            _data
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

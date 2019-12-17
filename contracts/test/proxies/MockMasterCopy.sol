pragma solidity >=0.5.0 <0.6.0;

import "../../proxies/MasterCopyNonUpgradable.sol";

contract MockMasterCopy is MasterCopyNonUpgradable {

    /** The callprefix of the Reputation::setup function. */
    bytes4 public constant SETUP_CALLPREFIX = bytes4(
        keccak256(
            "setup(uint256)"
        )
    );

    bool public isSetupCalled;
    uint256 public mockCount;

    function setup(uint256 _mockCount) external {
        require(
            isSetupCalled == false,
            "Setup can be called only once,"
        );
        isSetupCalled = true;
        mockCount = _mockCount;
    }

    function updateMockCount(uint256 _mockCount) external {
        mockCount = _mockCount;
    }

    function getSetupData(
        uint256 _mockCount
    )
        external
        pure
        returns(bytes memory setupData_)
    {
        setupData_ = abi.encodeWithSelector(
            SETUP_CALLPREFIX,
            _mockCount
        );
    }

    function getReservedStorageSlotForProxy() external view returns (address) {
        return reservedStorageSlotForProxy;
    }
}

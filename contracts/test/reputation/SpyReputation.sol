pragma solidity ^0.5.0;

import "../../reputation/ReputationI.sol";

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

import "../../reputation/ReputationI.sol";
import "../../proxies/MasterCopyNonUpgradable.sol";

contract SpyReputation is MasterCopyNonUpgradable, ReputationI {

    mapping(address /* validator */ => bool /* isActive */) public activeValidators;

    address public validator;

    address public consensus;
    address public most;
    uint256 public stakeMOSTAmount;
    address public wETH;
    uint256 public stakeWETHAmount;
    uint256 public cashableEarningsPerMille;
    uint256 public initialReputation;
    uint256 public withdrawalCooldownPeriodInBlocks;

    address public spyWithdrawalAddress;

    function setIsActive(
        address _validator,
        bool _active
    )
        external
    {
        activeValidators[_validator] = _active;
    }

    function isSlashed(
        address _validator
    )
        public
        view
        returns (bool)
    {
        return !activeValidators[_validator];
    }

    function setup(
        address _consensus,
        address _most,
        uint256 _stakeMOSTAmount,
        address _wETH,
        uint256 _stakeWETHAmount,
        uint256 _cashableEarningsPerMille,
        uint256 _initialReputation,
        uint256 _withdrawalCooldownPeriodInBlocks
    )
        external
    {
        consensus =_consensus;
        most = _most;
        stakeMOSTAmount =_stakeMOSTAmount;
        wETH = _wETH;
        stakeWETHAmount =_stakeWETHAmount;
        cashableEarningsPerMille =_cashableEarningsPerMille;
        initialReputation = _initialReputation;
        withdrawalCooldownPeriodInBlocks = _withdrawalCooldownPeriodInBlocks;
    }

    function getReservedStorageSlotForProxy() external view returns (address) {
        return reservedStorageSlotForProxy;
    }

    function stake(
        address _validator,
        address _withdrawalAddress
    )
        external
    {
        validator = _validator;
        spyWithdrawalAddress = _withdrawalAddress;
    }

    function deregister(address _validator) external {
        validator = _validator;
    }

    function getReputation(address) external view returns (uint256) {
        // This is not used in test so break
        require(false, "This should not be called for unit tests.");
    }
}

pragma solidity >=0.5.0 <0.6.0;

import "../../proxies/MasterCopyNonUpgradable.sol";
import "../../committee/CommitteeI.sol";

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

contract SpyCommittee is MasterCopyNonUpgradable, CommitteeI{

    bytes32 public mockedCommitteeDecision;

    bytes32 public spyMetachainId;
    address public spyConsensus;
    uint256 public spyCommitteeSize;
    bytes32 public spyDislocation;
    bytes32 public spyProposal;

    bool public isEnterCommitteeFunctionCalled;

    address public validator;
    address public furtherMember;

    function resetFunctionCallFlags()
        external
    {
        isEnterCommitteeFunctionCalled = false;
    }

    function enterCommittee(
        address _validator,
        address _furtherMember
    )
        external
    {
        validator = _validator;
        furtherMember = _furtherMember;
        isEnterCommitteeFunctionCalled = true;
    }

    function mockCommitteeDecision(bytes32 _committeeDecision) external {
        mockedCommitteeDecision = _committeeDecision;
    }

    function committeeDecision() external view returns (bytes32) {
        return mockedCommitteeDecision;
    }

    function setup(
        bytes32 _metachainId,
        address _consensus,
        uint256 _committeeSize,
        bytes32 _dislocation,
        bytes32 _proposal
    )
        external
    {
        spyMetachainId = _metachainId;
        spyConsensus = _consensus;
        spyCommitteeSize = _committeeSize;
        spyDislocation = _dislocation;
        spyProposal = _proposal;
    }

    function quorum() external view returns (uint256) {
        return uint256(1);
    }
}

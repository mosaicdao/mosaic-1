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

import "../../protocore/ProtocoreInterface.sol";

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract SpyCoconsensus {

    /* Usings */

    using SafeMath for uint256;


    /* Storage */

    mapping(bytes32 => address) public anchors;

    bytes32 public spyMetachainId;

    /* Functions */

    function setAnchorAddress(bytes32 _metachainId, address anchor) public {
        anchors[_metachainId] = anchor;
    }

    function getAnchor(bytes32 _metachainId) public returns(address) {
        spyMetachainId = _metachainId;
        return anchors[_metachainId];
    }

    function openKernel(
        ProtocoreInterface _protocore,
        bytes32 _kernelHash
    )
        external
    {
        uint256 openKernelHeight = _protocore.openKernelHeight();
        _protocore.openKernel(
            openKernelHeight.add(1),
            _kernelHash
        );
    }

    function finaliseCheckpoint(
        bytes32 metachainId,
        uint256 blockNumber,
        bytes32 blockHash
    )
        external
    {
    }


}

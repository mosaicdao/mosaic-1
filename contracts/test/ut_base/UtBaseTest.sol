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

import "./../../most/UtBase.sol";

/**
 * @title UtBaseTest contract.
 */
contract UtBaseTest is UtBase {

    /* Storage */

    CoconsensusInterface public coconsensus;

    address public consensusCogateway;


    /* Special Functions */

    /**
     * @notice UtBaseTest constructor.
     *
     * @param _coconsensus Coconsensus contract address.
     * @param _initialTokenSupply Initial token supply.
     */
    constructor(CoconsensusInterface _coconsensus, uint256 _initialTokenSupply)
        public
    {
        genesisTotalSupply = _initialTokenSupply;
        coconsensus = _coconsensus;
    }


    /* External Functions */

    /**
     * @notice It is used for testing purpose.
     * @param _consensusCogateway Consensus cogateway contract address.
     */
    function setConsensusCogateway(address _consensusCogateway) external {
        consensusCogateway = _consensusCogateway;
    }


    /* Public Functions */

    /**
     * @notice Gets the coconsensus contract address.
     *
     * @return Coconsensus contract address.
     */
    function getCoconsensus() public view returns (CoconsensusInterface) {
        return coconsensus;
    }

    function getConsensusCogateway() public view returns(address) {
        return consensusCogateway;
    }
}

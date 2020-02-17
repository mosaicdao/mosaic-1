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

import "./../../most/Utmost.sol";

/**
 * @title UtmostTest contract.
 */
contract UtmostTest is Utmost {

    /* Storage */

    CoconsensusInterface public coconsensus;


    /* Special Functions */

    /**
     * @notice UtmostTest constructor.
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


    /* Public Functions */

    /**
     * @notice Gets the coconsensus contract address.
     *
     * @return Coconsensus contract address.
     */
    function getCoconsensus() public view returns (CoconsensusInterface) {
        return coconsensus;
    }
}

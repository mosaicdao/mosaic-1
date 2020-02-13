pragma solidity >=0.5.0 <0.6.0;

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

import "../../consensus/Coconsensus.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract CoconsensusTest is Coconsensus {

    using SafeMath for uint256;

    address coreputation;
    address consensusCogateway;

    /**
     * @notice This function stores the genesis data.
     */
    function setGenesisStorage(
        bytes32[] calldata _metachainIds,
        address[] calldata _protocores,
        address[] calldata _observers
    )
        external
    {
        genesisOriginMetachainId = _metachainIds[0];
        genesisSelfMetachainId = _metachainIds[1];

        genesisMetachainIds[SENTINEL_METACHAIN_ID] = SENTINEL_METACHAIN_ID;
        for (uint256 i = 0; i < _metachainIds.length; i = i.add(1)) {
            bytes32 currentMetachainId = _metachainIds[i];

            genesisMetachainIds[currentMetachainId] = genesisMetachainIds[SENTINEL_METACHAIN_ID];
            genesisMetachainIds[SENTINEL_METACHAIN_ID] = currentMetachainId;

            genesisProtocores[currentMetachainId] = _protocores[i];
            genesisObservers[currentMetachainId] = _observers[i];
        }
    }

    /**
     * @notice This function is used to set the finalize checkpoint.
     */
    function setFinaliseCheckpoint(
        bytes32 _metachainId,
        uint256 _blockNumber,
        bytes32 _blockHash,
        uint256 _dynasty
    )
        external
    {
        blockchains[_metachainId][_blockNumber] = Block(
            _blockHash,
            CheckpointCommitStatus.Finalized,
            _dynasty
        );

        // Store the blocknumber as tip.
        blockTips[_metachainId] = _blockNumber;
    }

    /**
     * @notice This function sets the relative self dynasty for testing purpose.
     */
    function setRelativeSelfDynasty(uint256 _dynasty) external {
        relativeSelfDynasty = _dynasty;
    }


    function setCoreputation(address _coreputation) external {
        coreputation = _coreputation;
    }

    function setConsensusCogateway(address _consensusCogateway) external {
        consensusCogateway = _consensusCogateway;
    }

     /** @notice Get the coreputation contract address. */
    function getCoreputation()
        internal
        view
        returns (CoreputationInterface)
    {
        return CoreputationInterface(coreputation);
    }

    /** @notice Get the consensus cogateway contract address. */
    function getConsensusCogateway()
        internal
        view
        returns (ConsensusCogatewayInterface)
    {
        return ConsensusCogatewayInterface(consensusCogateway);
    }
}

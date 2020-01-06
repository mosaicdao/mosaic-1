pragma solidity >=0.5.0 <0.6.0;
import "../../consensus-gateway/ConsensusCoGateway.sol";

contract MockConsensusCogateway is ConsensusCogateway {

constructor()
 public
 ConsensusCogateway()
 { }

function setupInitialData(address _storageAccount, StateRootI _stateRootProvider, uint256 _maxStorageRootItems) public {
    storageAccount = _storageAccount;
    stateRootProvider = _stateRootProvider;

    encodedAccountPath = BytesLib.bytes32ToBytes(
        keccak256(abi.encodePacked(_storageAccount))
    );

    CircularBufferUint.setupCircularBuffer(_maxStorageRootItems);
}

}

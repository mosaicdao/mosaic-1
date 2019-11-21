pragma solidity ^0.5.0;

contract CoreStatusEnum {
    /* Enum and structs */

    /** Enum of Core state machine */
    enum CoreStatus {
        // core is undefined.
        undefined,
        // core has failed to get a proposal committed when challenged for being halted
        halted,
        // precommitted proposal is rejected by consensus committee
        corrupted,
        // core accepts initial set of validators
        creation,
        // core has an open kernel without precommitment to a proposal
        opened,
        // core has precommitted to a proposal for the open kernel
        precommitted
    }
}

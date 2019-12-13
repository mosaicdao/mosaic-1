pragma solidity ^0.5.0;

contract CoreStatusEnum {
    /* Enum and structs */

    /** Enum of Core state machine */
    enum CoreStatus {
        // core is undefined.
        undefined,
        // core has been terminated.
        terminated,
        // core accepts initial set of validators.
        created,
        // core has an open kernel without precommitment to a proposal
        opened,
        // core has precommitted to a proposal for the open kernel
        precommitted
    }
}

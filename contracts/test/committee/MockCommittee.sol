pragma solidity ^0.5.0;
import "../../committee/Committee.sol";

/**
 * It provides helper methods for testing.
 */
contract MockCommittee is Committee {

    /** Special Functions */

    constructor()
    public
    Committee()
    { }


    /** Public Functions */

    /**
     * Sets committee status to closed.
     */
    function setCommitteeStatusToClosed() public {
        committeeStatus = CommitteeStatus.Closed;
    }
}

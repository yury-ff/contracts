// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "../tokens/MintableBaseToken.sol";

contract FidFF is MintableBaseToken {
    constructor() MintableBaseToken("Fiduciary FF", "FidFF", 0) {}

    function id() external pure returns (string memory _name) {
        return "FidFF";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "../tokens/MintableBaseToken.sol";

contract FF is MintableBaseToken {
    constructor() MintableBaseToken("FF", "FF", 0) {}

    function id() external pure returns (string memory _name) {
        return "FF";
    }
}

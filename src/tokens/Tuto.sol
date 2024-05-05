// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20, ERC20Burnable} from "../libraries/ERC20Burnable.sol";
import {ERC20Permit} from "../libraries/ERC20Permit.sol";
import {Ownable} from "../libraries/Ownable.sol";

contract Tuto is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    
    bool public limited;   
    uint256 public maxHoldingAmount;
    uint256 public minHoldingAmount;
    address public uniswapV2Pair;

 constructor(address _initialOwner, uint256 _totalSupply) ERC20("Tuto", "TUTO") ERC20Permit("Tuto") Ownable(_initialOwner) {
        _mint(msg.sender, _totalSupply);
    }

    function setRule(bool _limited, address _uniswapV2Pair, uint256 _maxHoldingAmount, uint256 _minHoldingAmount) external onlyOwner {
        limited = _limited;
        uniswapV2Pair = _uniswapV2Pair;
        maxHoldingAmount = _maxHoldingAmount;
        minHoldingAmount = _minHoldingAmount;
    }

    function _update(address from, address to, uint256 value) override internal virtual {
        if (limited == true) {
            _beforeUniswap(from, to, value);
            }
        super._update(from, to, value);
    }

    function _beforeUniswap(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (limited && from == uniswapV2Pair) {
            require(super.balanceOf(to) + amount <= maxHoldingAmount && super.balanceOf(to) + amount >= minHoldingAmount, "Forbid");
        }
    }
   
}

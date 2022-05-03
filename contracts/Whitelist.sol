// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Operator.sol";

contract Whitelist is Operator {
    uint256 public total = 0;
    mapping(address => bool) public isWhitelisted;

    event AddressWhitelisted(address indexed addr, address operator);
    event AddressRemovedFromWhitelist(address indexed addr, address operator);

    modifier onlyWhitelisted(address _address) {
        require(isWhitelisted[_address], "Address is not on the whitelist.");
        _;
    }

    function addToWhitelist(address _newAddr) public onlyOperator {
        require(_newAddr != address(0), "Invalid new address.");

        require(!isWhitelisted[_newAddr], "Address is already whitelisted.");

        isWhitelisted[_newAddr] = true;
        total++;
        emit AddressWhitelisted(_newAddr, msg.sender);
    }

    function removeFromWhitelist(address _addr) public onlyOperator {
        require(_addr != address(0), "Invalid address.");

        require(isWhitelisted[_addr], "Address not in whitelist.");

        isWhitelisted[_addr] = false;
        if (total > 0) {
            total--;
        }
        emit AddressRemovedFromWhitelist(_addr, msg.sender);
    }

    function whitelistAddresses(address[] memory _addresses, bool _whitelisted)
        public
        onlyOperator
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            address addr = _addresses[i];
            if (isWhitelisted[addr] == _whitelisted) continue;
            if (_whitelisted) {
                addToWhitelist(addr);
            } else {
                removeFromWhitelist(addr);
            }
        }
    }
}

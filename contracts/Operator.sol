// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Ownable.sol";

contract Operator is Ownable {
    address[] public operators;

    uint256 public MAX_OPS = 20;

    mapping(address => bool) public isOperator;

    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);

    modifier onlyOperator() {
        require(
            isOperator[msg.sender] || msg.sender == owner,
            "Permission denied. Must be an operator or the owner."
        );
        _;
    }

    function addOperator(address _newOperator) public onlyOwner {
        require(_newOperator != address(0), "Invalid new operator address.");

        require(!isOperator[_newOperator], "New operator exists.");

        require(operators.length < MAX_OPS, "Overflow.");

        operators.push(_newOperator);
        isOperator[_newOperator] = true;

        emit OperatorAdded(_newOperator);
    }

    function removeOperator(address _operator) public onlyOwner {
        // Make sure operators array is not empty
        require(operators.length > 0, "No operator.");

        require(isOperator[_operator], "Not an operator.");

        address lastOperator = operators[operators.length - 1];
        for (uint256 i = 0; i < operators.length; i++) {
            if (operators[i] == _operator) {
                operators[i] = lastOperator;
            }
        }
        delete operators[operators.length - 1];
        isOperator[_operator] = false;
        emit OperatorRemoved(_operator);
    }

    function removeAllOps() public onlyOwner {
        for (uint256 i = 0; i < operators.length; i++) {
            isOperator[operators[i]] = false;
        }
        delete operators;
    }
}

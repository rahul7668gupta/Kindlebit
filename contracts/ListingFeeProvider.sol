// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Operator.sol";

contract ListingFeeProvider is Operator {
    // @dev Since default uint value is zero, need to distinguish Default vs No Fee
    uint256 constant NO_FEE = 10000;

    uint256 defaultPercentFee = 500; // default fee: 5%

    mapping(bytes32 => uint256) public customFee; // Allow buyer or seller or game discounts

    event LogFeeChanged(
        uint256 newPercentFee,
        uint256 oldPercentFee,
        address operator
    );
    event LogCustomFeeChanged(
        uint256 newPercentFee,
        uint256 oldPercentFee,
        address buyer,
        address seller,
        address token,
        address operator
    );

    /**
     * @dev Allow operators to update the fee for a custom combo
     * @param _newFee New fee in percent x 100 (to support decimals)
     */
    function updateFee(uint256 _newFee) public onlyOperator {
        require(_newFee >= 0 && _newFee <= 10000, "Invalid percent fee.");

        uint256 oldPercentFee = defaultPercentFee;
        defaultPercentFee = _newFee;

        emit LogFeeChanged(_newFee, oldPercentFee, msg.sender);
    }

    /**
     * @dev Allow operators to update the fee for a custom combo
     * @param _newFee New fee in percent x 100 (to support decimals)
     *                enter zero for default, 10000 for No Fee
     */
    function updateCustomFee(
        uint256 _newFee,
        address _currency,
        address _buyer,
        address _seller,
        address _token
    ) public onlyOperator {
        require(_newFee >= 0 && _newFee <= 10000, "Invalid percent fee.");

        bytes32 key = _getHash(_currency, _buyer, _seller, _token);
        uint256 oldPercentFee = customFee[key];
        customFee[key] = _newFee;

        emit LogCustomFeeChanged(
            _newFee,
            oldPercentFee,
            _buyer,
            _seller,
            _token,
            msg.sender
        );
    }

    /**
     * @dev Calculate the custom fee based on buyer, seller, game token or combo of these
     */
    function getFee(
        uint256 _price,
        address _currency,
        address _buyer,
        address _seller,
        address _token
    ) public view returns (uint256 percent, uint256 fee) {
        bytes32 key = _getHash(_currency, _buyer, _seller, _token);
        uint256 customPercentFee = customFee[key];
        (percent, fee) = _getFee(_price, customPercentFee);
    }

    function _getFee(uint256 _price, uint256 _percentFee)
        internal
        view
        returns (uint256 percent, uint256 fee)
    {
        require(_price >= 0, "Invalid price.");

        percent = _percentFee;

        // No data, set it to default
        if (_percentFee == 0) {
            percent = defaultPercentFee;
        }

        // Special value to set it to zero
        if (_percentFee == NO_FEE) {
            percent = 0;
            fee = 0;
        } else {
            fee = _safeMul(_price, percent) / 10000; // adjust for percent and decimal. division always truncate
        }
    }

    // get custom fee hash
    function _getHash(
        address _currency,
        address _buyer,
        address _seller,
        address _token
    ) internal pure returns (bytes32 key) {
        key = keccak256(abi.encodePacked(_currency, _buyer, _seller, _token));
    }

    // safe multiplication
    function _safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }
}

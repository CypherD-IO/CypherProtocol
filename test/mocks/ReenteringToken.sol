// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {TestToken} from "./TestToken.sol";

contract ReenteringToken is TestToken {
    address target;
    bytes data;

    function setCall(address _target, bytes memory _data) external {
        target = _target;
        data = _data;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (target != address(0)) {
            (bool ok, bytes memory err) = target.call{value: 0}(data);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(err, 0x20), mload(err))
                }
            }
            target = address(0);
        }

        super._update(from, to, value);
    }
}

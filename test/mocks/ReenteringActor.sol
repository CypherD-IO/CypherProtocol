// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

contract ReenteringActor {
    address private target;

    function setTarget(address _target) external {
        target = _target;
    }

    function makeCall(bytes memory data) external {
        (bool ok, bytes memory err) = target.call{value: 0}(data);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(err, 0x20), mload(err))
            }
        }
    }
}

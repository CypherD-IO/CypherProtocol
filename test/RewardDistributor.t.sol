pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {CypherToken} from "../src/CypherToken.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";
import {IRewardDistributor} from "../src/interfaces/IRewardDistributor.sol";

contract RewardDistributorTest is Test {
    CypherToken cypher;
    RewardDistributor rd;

    function setUp() public {
        cypher = new CypherToken(address(this));
        rd = new RewardDistributor(address(this), address(cypher));
    }

    function testConstruction() public {
        RewardDistributor rewardDistributor = new RewardDistributor(address(0x1234), address(0x9876));
        assertEq(rewardDistributor.owner(), address(0x1234));
        assertEq(address(rewardDistributor.cypher()), address(0x9876));
    }

    function testAddRoot() public {
        bytes32 root1 = keccak256(bytes.concat("abc"));
        uint256 id = rd.addRoot(root1);
        assertEq(id, 0);
        assertEq(rd.idToRoot(id), root1);
        bytes32 root2 = keccak256(bytes.concat("123"));
        id = rd.addRoot(root2);
        assertEq(id, 1);
        assertEq(rd.idToRoot(id), root2);
    }

    function testAddSameRootTwice() public {
        bytes32 root = keccak256(bytes.concat("a1A"));
        uint256 id = rd.addRoot(root);
        assertEq(id, 0);
        assertEq(rd.idToRoot(id), root);
        id = rd.addRoot(root);
        assertEq(id, 1);
        assertEq(rd.idToRoot(id), root);
    }

    function testZeroBytes32IsNotAValidRoot() public {
        vm.expectRevert(IRewardDistributor.InvalidRoot.selector);
        rd.addRoot(bytes32(0));
    }

    function testOnlyOwnerCanAddARoot() public {
        address other = address(0xF00);
        assertTrue(rd.owner() != other);
        bytes32 root = bytes32(bytes1(0x11));
        vm.prank(other);
        vm.expectRevert();
        rd.addRoot(root);
    }

    function testClaimSingle() public {
        address[] memory addrs = new address[](4);
        uint256[] memory amnts = new uint256[](4);

        addrs[0] = address(0x1234);
        addrs[1] = address(0x6789);
        addrs[2] = address(0x8888);
        addrs[3] = address(0xF1F0);

        amnts[0] = 5e18;
        amnts[1] = 2.7e18;
        amnts[2] = 555e18;
        amnts[3] = 0.01e18;

        bytes32 root;
        bytes32[] memory proof;
        for (uint256 proofIdx = 0; proofIdx < 4; proofIdx++) {
            (root, proof) = _computeSimpleTree(addrs, amnts, proofIdx);
            uint256 id = rd.addRoot(root);

            address claimant = addrs[proofIdx];
            uint256 claimAmt = amnts[proofIdx];

            cypher.transfer(address(rd), claimAmt);
            uint256 balBefore = cypher.balanceOf(claimant);

            vm.prank(claimant);
            rd.claim(proof, id, claimAmt);

            uint256 balAfter = cypher.balanceOf(claimant);
            assertEq(balAfter - balBefore, claimAmt);
            assertTrue(rd.claimed(id, claimant));
        }
    }

    function testClaimInvalidRootId() public {
        (bytes32 root, bytes32[] memory proof, address addr, uint256 amnt) = _genValidRootAndClaimData();
        uint256 id = rd.addRoot(root);
        cypher.transfer(address(rd), amnt);

        // Everything is correct except root id is off-by-one and hasn't been added
        vm.prank(addr);
        vm.expectRevert(abi.encodeWithSelector(IRewardDistributor.InvalidRootId.selector, id + 1));
        rd.claim(proof, id + 1, amnt);
    }

    function testCannotClaimTwice() public {
        (bytes32 root, bytes32[] memory proof, address addr, uint256 amnt) = _genValidRootAndClaimData();
        uint256 id = rd.addRoot(root);
        cypher.transfer(address(rd), 2 * amnt); // transfer enough to claim twice

        vm.startPrank(addr);
        rd.claim(proof, id, amnt);
        vm.expectRevert(abi.encodeWithSelector(IRewardDistributor.AlreadyClaimed.selector, id));
        rd.claim(proof, id, amnt);
    }

    function testInvalidProofIsRejected() public {
        (bytes32 root, bytes32[] memory proof, address addr, uint256 amnt) = _genValidRootAndClaimData();
        uint256 id = rd.addRoot(root);
        cypher.transfer(address(rd), amnt);

        // mangle proof
        proof[1] = bytes32(0);

        vm.startPrank(addr);
        vm.expectRevert(abi.encodeWithSelector(IRewardDistributor.InvalidProof.selector, id));
        rd.claim(proof, id, amnt);
    }

    function testClaimMultiple() public {
        address[] memory addrs = new address[](4);
        uint256[] memory amnts = new uint256[](4);

        addrs[0] = address(0x1234);
        addrs[1] = address(0x6789);
        addrs[2] = address(0x8888);
        addrs[3] = address(0xF1F0);

        amnts[0] = 2e18;
        amnts[1] = 8e18;
        amnts[2] = 0.617e18;
        amnts[3] = 1.38e18;

        uint256[] memory values = new uint256[](2);
        values[0] = amnts[3];
        (bytes32 root1, bytes32[] memory proof1) = _computeSimpleTree(addrs, amnts, 3);

        // change the amount at the index chosen for the proof
        amnts[3] = 7.1e18;
        values[1] = amnts[3];
        (bytes32 root2, bytes32[] memory proof2) = _computeSimpleTree(addrs, amnts, 3);

        uint256[] memory rootIds = new uint256[](2);
        rootIds[0] = rd.addRoot(root1);
        rootIds[1] = rd.addRoot(root2);

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = proof1;
        proofs[1] = proof2;

        cypher.transfer(address(rd), values[0] + values[1]);

        vm.prank(addrs[3]);
        rd.claimMultiple(proofs, rootIds, values);

        assertEq(cypher.balanceOf(addrs[3]), values[0] + values[1]);
        assertTrue(rd.claimed(rootIds[0], addrs[3]));
        assertTrue(rd.claimed(rootIds[1], addrs[3]));
    }

    // This test documents the fact that roots may be duplicated in the contract with no issues.
    function testClaimMultipleDuplicatedRoot() public {
        (bytes32 root, bytes32[] memory proof, address addr, uint256 amnt) = _genValidRootAndClaimData();

        uint256[] memory rootIds = new uint256[](2);
        rootIds[0] = rd.addRoot(root);
        rootIds[1] = rd.addRoot(root);

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = proof;
        proofs[1] = proof;

        uint256[] memory values = new uint256[](2);
        values[0] = amnt;
        values[1] = amnt;

        cypher.transfer(address(rd), 2 * amnt);

        vm.prank(addr);
        rd.claimMultiple(proofs, rootIds, values);

        assertEq(cypher.balanceOf(addr), 2 * amnt);
        assertTrue(rd.claimed(rootIds[0], addr));
        assertTrue(rd.claimed(rootIds[1], addr));
    }

    function testClaimMultipleArrayLengthMismatches() public {
        (bytes32 root, bytes32[] memory proof, address addr, uint256 amnt) = _genValidRootAndClaimData();

        uint256[] memory rootIds = new uint256[](2);
        rootIds[0] = rd.addRoot(root);
        rootIds[1] = rd.addRoot(root);

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = proof;
        proofs[1] = proof;

        uint256[] memory values = new uint256[](2);
        values[0] = amnt;
        values[1] = amnt;

        cypher.transfer(address(rd), 2 * amnt);

        uint256[] memory tooManyRootIds = new uint256[](3);
        tooManyRootIds[0] = rootIds[0];
        tooManyRootIds[1] = rootIds[1];
        vm.prank(addr);
        vm.expectRevert(IRewardDistributor.LengthMismatch.selector);
        rd.claimMultiple(proofs, tooManyRootIds, values);

        bytes32[][] memory tooFewProofs = new bytes32[][](1);
        tooFewProofs[0] = proof;
        vm.prank(addr);
        vm.expectRevert(IRewardDistributor.LengthMismatch.selector);
        rd.claimMultiple(tooFewProofs, rootIds, values);

        uint256[] memory tooManyValues = new uint256[](4);
        tooManyValues[0] = values[0];
        tooManyValues[1] = values[1];
        tooManyValues[2] = 1e18;
        tooManyValues[3] = 0;
        vm.prank(addr);
        vm.expectRevert(IRewardDistributor.LengthMismatch.selector);
        rd.claimMultiple(proofs, rootIds, tooManyValues);
    }

    function _genValidRootAndClaimData()
        internal
        pure
        returns (bytes32 root, bytes32[] memory proof, address addr, uint256 amnt)
    {
        address[] memory addrs = new address[](4);
        uint256[] memory amnts = new uint256[](4);

        addrs[0] = address(0x1234);
        addrs[1] = address(0x6789);
        addrs[2] = address(0x8888);
        addrs[3] = address(0xF1F0);

        amnts[0] = 5e18;
        amnts[1] = 2.7e18;
        amnts[2] = 555e18;
        amnts[3] = 0.01e18;

        (root, proof) = _computeSimpleTree(addrs, amnts, 0);
        addr = addrs[0];
        amnt = amnts[0];
    }

    function _computeSimpleTree(address[] memory addrs, uint256[] memory amnts, uint256 proofIdx)
        internal
        pure
        returns (bytes32 root, bytes32[] memory proof)
    {
        proof = new bytes32[](2);

        bytes32[] memory leafHashes = new bytes32[](4);
        for (uint256 i = 0; i < 4; i++) {
            leafHashes[i] = keccak256(bytes.concat(keccak256(abi.encode(addrs[i], amnts[i]))));
        }

        proof[0] = leafHashes[(proofIdx + 1) % 2 + (proofIdx / 2) * 2];

        bytes32 leftHash = _commutativeKeccak(leafHashes[0], leafHashes[1]);
        bytes32 rightHash = _commutativeKeccak(leafHashes[2], leafHashes[3]);

        proof[1] = proofIdx < 2 ? rightHash : leftHash;

        root = keccak256(bytes.concat(leftHash, rightHash));
        root = _commutativeKeccak(leftHash, rightHash);
    }

    function _commutativeKeccak(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(bytes.concat(a, b)) : keccak256(bytes.concat(b, a));
    }
}

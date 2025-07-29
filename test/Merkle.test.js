import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { ethers } from "ethers";

const values = [
    [ "0x1111111111111111111111111111111111111111",  "1000000000000000000" ],
    [ "0x2222222222222222222222222222222222222222",  "3500000000000000000" ],
    [ "0x3333333333333333333333333333333333333333", "12000007000000000000" ],
    [ "0x4444444444444444444444444444444444444444",  "9999999999999999999" ],
    [ "0x5555555555555555555555555555555555555555",  "4444333333322229687" ],
    [ "0x6666666666666666666666666666666666666666",  "8888888888888888888" ],
    [ process.argv[2], process.argv[3] ]
]

const tree = StandardMerkleTree.of(values, ["address", "uint256"]);

// ffi expects a hex string abi encoding
const enc = ethers.AbiCoder.defaultAbiCoder().encode(
    [ "bytes32", "bytes32[]" ],
    [ tree.root, tree.getProof(6) ]
);
console.log(enc);

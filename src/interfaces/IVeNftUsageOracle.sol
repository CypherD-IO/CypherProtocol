// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice This interface is primarily to allow the VotingEscrow contract to know when it is safe to perform operations
///         like merging veNFTs that could subvert ongoing voting processes. It is separate from the IElection contract
///         because the veNFTs may one day be used for other governance purposes than simply distributing CYPR incentives.
interface IVeNftUsageOracle {
    /// @notice Informs the caller whether or not a particular veNFT's voting power is in use.
    /// @param tokenId The id of the veNFT to query the usage status of.
    /// @return inUse Whether or not the veNFT's voting power is currently in use.
    function isInUse(uint256 tokenId) external view returns (bool inUse);
}

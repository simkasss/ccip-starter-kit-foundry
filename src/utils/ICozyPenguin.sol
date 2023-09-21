// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract ICozyPenguin {
    function ownerOf(uint256 tokenId) public view virtual returns (address);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual;
}

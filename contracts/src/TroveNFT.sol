// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

import "./Interfaces/ITroveManager.sol";
import "./Interfaces/ITroveNFT.sol";


contract TroveNFT is ERC721, ITroveNFT {
    string public constant NAME = "TroveNFT"; // TODO
    string public constant SYMBOL = "Lv2T"; // TODO

    ITroveManager public immutable troveManager;

    constructor(ITroveManager _troveManager) ERC721(NAME, SYMBOL) {
        troveManager = _troveManager;
    }

    function mint(address _owner, uint256 _troveId) external override {
        _requireCallerIsTroveManager();
        _mint(_owner, _troveId);
    }

    function burn(uint256 _troveId) external override {
        _requireCallerIsTroveManager();
        _burn(_troveId);
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == address(troveManager), "TroveNFT: Caller is not the TroveManager contract");
    }
}

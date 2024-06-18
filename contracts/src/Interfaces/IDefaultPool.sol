// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IDefaultPool {
    function setAddresses(address _troveManagerAddress, address _activePoolAddress) external;
    function troveManagerAddress() external view returns (address);
    function activePoolAddress() external view returns (address);
    // --- Functions ---
    function getCollBalance() external view returns (uint256);
    function getBoldDebt() external view returns (uint256);
    function sendCollToActivePool(uint256 _amount) external;
    function receiveColl(uint256 _amount) external;

    function increaseBoldDebt(uint256 _amount) external;
    function decreaseBoldDebt(uint256 _amount) external;
}

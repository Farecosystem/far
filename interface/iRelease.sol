// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

interface iRelease{

    function myInfo() external view returns(uint freezeA,uint drawdA,uint claimableA);

    function drawRelease() external returns(uint v);

    function claimAirDrop()external returns(uint v);
}
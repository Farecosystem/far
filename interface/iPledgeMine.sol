// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

interface iPledgeMine{
    
    function getPledgeInfo()external view returns(
        uint[] memory totalAmounts,
        uint[] memory apys);

    function getMyInfos()external view returns(
        uint[]memory amounts,
        uint[] memory apys,
        uint[] memory tvls
        );


    function doPledge(uint pledge,uint amount)external returns(bool);

    function doUnPledge(uint pledge,uint amount) external returns(bool);

    function doFreeze(uint pledge,uint finesLevel) external returns (bool);

    function doDraw()external returns(bool);

    function getAwardInfo()external returns(
        uint totalFreeze,
        uint totalAward,
        uint[] memory awards
        );

    function getClaimConditions()external view returns(
        uint[] memory lockDays,
        uint[] memory punishRates,
        uint[] memory acquireRates);

    function getFinesInfo() external view returns(uint[] memory finesAmounts);

    function doClaimAirDrop(address owner)external  returns(uint);

}
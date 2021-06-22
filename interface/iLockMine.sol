// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

interface iLockMine{
    
    function getLockAmounts(address[] calldata owners) external view returns(uint[] memory values);

    function getNetworkInfo()external view returns(uint[] memory totalAmounts,uint[] memory apys);

    function getMyInfos()external view returns(
        uint[] memory lockTotalAmounts,
        uint[]memory lockAmounts,
        uint[] memory earnings,
        uint[] memory times,
        uint[] memory apys,
        bool[] memory lockables
        );

    function doAddLockOnePeriod(uint lock) external returns(bool);

    function getMyInfoDetail()external view returns(
        uint[]memory lockAmounts,
        uint[] memory drawedEarnings,
        uint[] memory times,
        uint[] memory claimables,
        uint[] memory unLockables,
        bool[] memory extendible
        );


    function doDraw()external returns(
        uint totalLock,
        uint totalAward,
        uint[] memory awards
        );

    function getAwardInfo()external returns(
        uint totalLock,
        uint totalAward,
        uint[] memory awards
        );

    function doLock(uint lock,uint amount) external returns(bool);

    
    function doUnLock(uint lock) external returns(bool);

    function injectFines(uint amount)external returns(bool);

    function getFinesInfo() external view returns(uint month,uint quarter,uint year);
}
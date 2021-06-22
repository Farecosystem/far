// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

interface iPowerMine{

    function changePower(address owner ,uint amount,bool isAdd) external  returns(bool);


    function mineInfo() external view returns(
        uint networkPower,
        uint myPower
        );

    function doDraw()external returns(uint);

    function injectFines(uint amount)external returns(bool);

    function getFinesInfo() external view returns(uint);
}
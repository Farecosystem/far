// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

import "./k_noUpgradeable.sol";
import "./IERC20.sol";
import "./iRelation.sol";
import "./iLockMine.sol";
import "./TimeLineValuePower.sol";

contract PowerMineStorage is KOwnerable {

    using TimeLineValuePower for TimeLineValuePower.Data;

    TimeLineValuePower.Data internal mineManager;

    mapping(address => mapping(address => uint)) internal hasForMeProvidePower;

    uint[] internal conditionBySharePower = [
        100e18,
        200e18,
        300e18,
        400e18,
        500e18,
        600e18,
        700e18,
        800e18,
        900e18,
        1000e18];

    iERC20 internal mineToken;
    iRelation internal relation;

    uint internal powerPropagateDepth = 10;

    uint internal powerPropagateRate = 10;
    
    iLockMine internal lockMine;   
}

contract PowerMine is PowerMineStorage {

    constructor(
        iERC20 _mineToken,
        iRelation _relation,
        uint everyDay )public{

        mineToken = _mineToken;
        relation = _relation;    
        mineManager.initNetwork(1 days,15);
        mineManager.changeEveryInterval(everyDay,timestempZero(),true);
    }

/////////////////////////////////manage///////////////////////////
/////////////////////////////////manage///////////////////////////

    function mSetLockMine(address _lockMine)external KOwnerOnly returns(bool){
        lockMine = iLockMine(_lockMine);
        return true;
    }

    function mGetMinedEveryDay()external view KOwnerOnly returns(uint v){
        v = mineManager.intervalValueLastValue();
    }

    function mSetMinedEveryDay(uint change, bool isAdd) external KOwnerOnly returns(bool){
        if( change > 0 ){
            mineManager.changeEveryInterval(change,timestempZero(),isAdd);
        }
        return true;
    }

    function mSetPowerPropagateDepth(uint depth) external KOwnerOnly returns(bool){
        powerPropagateDepth = depth;
        return true;
    }

/////////////////////////////////read///////////////////////////
/////////////////////////////////read///////////////////////////

    function mineInfo() external view returns(
        uint networkPower,
        uint myPower){
        networkPower = mineManager.networkLastvalue();
        myPower = mineManager.personalLastValue(msg.sender);
    }
    
    function getFinesInfo() external view returns(uint){
        uint time = timestempZero();
        return mineManager.bestMatchIntervalValueReset(time);
    }


/////////////////////////////////write///////////////////////////
/////////////////////////////////write///////////////////////////

    function doDraw() external KRejectContractCall returns (uint) {  

        uint todayZero = timestempZero();

        uint v = mineManager.drawAward(msg.sender,todayZero);

        if( v > 0 ){
            mineToken.transfer(msg.sender, v);
        }
        return v;
    }

    function changePower(address owner,uint amount,bool isAdd) external KDelegateMethod returns(bool) {

        uint todayZero = timestempZero();

        uint changeAmount = amount * powerPropagateRate / 100;

        address[] memory recommers = relation.getRecommers(owner,powerPropagateDepth);

        uint len = recommers.length;
        if( len == 0) return true;

        if( isAdd ){

            uint[] memory values = lockMine.getLockAmounts(recommers);

            for( uint i = 0; i < len; i ++ ){

                if( conditionBySharePower[i] <= values[i] ){
                    hasForMeProvidePower[owner][recommers[i]] += changeAmount;
                }else{
                    recommers[i] = address(0);
                }
            }
            mineManager.addDatas(recommers,changeAmount,todayZero);

        }else{

            uint[] memory amounts = new uint[](len);

            for( uint i = 0; i < len; i ++ ){

                uint providerPower = hasForMeProvidePower[owner][recommers[i]];

                if( providerPower > 0 ){
                    amounts[i] = providerPower > changeAmount ? changeAmount : providerPower;
                    hasForMeProvidePower[owner][recommers[i]] = (providerPower - amounts[i]);
                }
                
            }        
            mineManager.subDatas(recommers,amounts,todayZero);
        }
        
        return true;
    }

    function injectFines(uint amount)external KDelegateMethod returns(bool){
        mineManager.changeEveryIntervalReset(amount,timestempZero());
        return true;
    }


    
}
// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

import "./k_noUpgradeable.sol";
import "./IERC20.sol";
import "./iRelation.sol";
import "./iPowerMine.sol";
import "./TimeLineValueLock.sol";
import "./TimeLineValueFreeze.sol";

contract LockMineStorage is KOwnerable {

    enum Pool{
        MonthPool,
        QuarterPool,
        YearPool
    }

    uint internal sealTimes = 5 * 86400;

    struct LockInfo{
        uint lockAmounts;
        uint period;
        uint everyDayMine;
        uint startTime; 
        uint sealTime;
    }

    using TimeLineValueLock for TimeLineValueLock.Data;
    using TimeLineValueFreeze for TimeLineValueFreeze.Data;

    mapping(uint => TimeLineValueLock.Data)internal mineManagers;

    LockInfo[] internal lockInfos;

    struct Miner{
        uint value;
        mapping(uint => uint) mineds;
        mapping(uint => TimeLineValueFreeze.Data) freezeManagers;
    }
    
    mapping( address => Miner) internal miners;

    iRelation internal relation;

    iERC20 internal mineToken;

    iPowerMine internal powerMine;

    uint[] internal allotFinesConfig = [15,35,50];

    uint[] internal lockAmountMultiples = [1,5,15];

    bool public isStart = false;
}

contract LockMine is LockMineStorage{

    constructor(
            iERC20 _token,
            iRelation _relation,
            iPowerMine _powerMine,
            uint[] memory periods,
            uint[] memory everyDays)public{

            relation = _relation;
            mineToken = _token;
            powerMine = _powerMine;

            uint initTime = timestempZero();
            uint sealTime = initTime  + sealTimes;

            uint len = periods.length;
            for( uint i = 0; i < len; i++){
                lockInfos.push(LockInfo(0,periods[i],everyDays[i],initTime,sealTime));
            }
    }
///////////////////////////////////////manage/////////////////////////
///////////////////////////////////////manage/////////////////////////
    function mStartLockMine() external KOwnerOnly returns(bool){

        require(!isStart,"is_start");
        uint initTime = timestempZero();
        uint sealTime = initTime  + sealTimes;

        uint len = lockInfos.length;
        for( uint i = 0; i < len; i++){

            LockInfo storage info = lockInfos[i];

            mineManagers[i].initNetwork(info.period,initTime,sealTime,15);

            mineManagers[i].changeEveryInterval(info.everyDayMine,initTime);
            info.startTime = initTime;
            info.sealTime = sealTime;
        }
        isStart = true;
        return true;
    }
    

    function mGetMinedEveryDay(uint lock) external view KOwnerOnly returns(uint v){
        v = mineManagers[lock].lastValue(timestempZero());
    }

    function mSetMinedEveryDay(uint lock,uint everyDay) external KOwnerOnly returns(bool){
        if(everyDay > 0){
            mineManagers[lock].changeEveryInterval(everyDay,timestempZero());
        }
        return true;
    }

///////////////////////////////////////read/////////////////////////
///////////////////////////////////////read/////////////////////////


    function _getApy(uint index,LockInfo storage lock)internal view returns(uint){

        uint denominator = lock.lockAmounts;

        uint base = mineManagers[index].intervalValueLastValue(timestempZero())  * 365;

        if( denominator == 0 ){
            return base / 1e18;
        }
        return base / denominator;
    }

    function getNetworkInfo()external view returns(uint[] memory totalAmounts,uint[] memory apys){

        totalAmounts = new uint[](lockInfos.length);
        apys = new uint[](lockInfos.length);

        for( uint i = 0; i < lockInfos.length; i++){
            totalAmounts[i] = lockInfos[i].lockAmounts;
            apys[i] = _getApy(i,lockInfos[i]);
        }
        return (totalAmounts,apys);
    }

    function getMyInfos()external view returns(
        uint[] memory lockTotalAmounts,
        uint[]memory lockAmounts,
        uint[] memory earnings,
        uint[] memory times,
        uint[] memory apys,
        bool[] memory lockables){

        uint len = lockInfos.length;
        lockTotalAmounts = new uint[](len);
        lockAmounts = new uint[](len);
        earnings = new uint[](len);
        times = new uint[](len);
        apys = new uint[](len);
        lockables = new bool[](len);

        Miner storage miner = miners[msg.sender];

        uint time = timestempZero();

        for( uint i = 0; i < len; i++){

            LockInfo storage info = lockInfos[i];

            apys[i] = _getApy(i,lockInfos[i]);
            (lockables[i],times[i]) = _checkHasLockable(info,time);
            lockTotalAmounts[i] = info.lockAmounts;
            lockAmounts[i] = miner.freezeManagers[i].total;
            earnings[i] = miner.mineds[i] ;
        }

        return (lockTotalAmounts,lockAmounts,earnings,times,apys,lockables);
    }


    function getMyInfoDetail()external view returns(
        uint[]memory lockAmounts,
        uint[] memory drawedEarnings,
        uint[] memory times,
        uint[] memory claimables,
        uint[] memory unLockables,
        bool[] memory extendible){

        uint len = lockInfos.length;

        lockAmounts = new uint[](len);
        drawedEarnings = new uint[](len);
        times = new uint[](len);
        unLockables = new uint[](len);
        extendible = new bool[](len);
        claimables = new uint[](len);

        Miner storage miner = miners[msg.sender];

        uint time = timestempZero();

        for( uint i = 0; i < len; i++){

            LockInfo storage info = lockInfos[i];

            lockAmounts[i] = miner.freezeManagers[i].total;
            drawedEarnings[i] = miner.mineds[i];

            (bool lockable,uint t) = _checkHasLockable(info,time);
            times[i] = t;

            unLockables[i] = miner.freezeManagers[i].getUnFreezeable(time);

            if( lockable && miner.freezeManagers[i].getUnFreezeable(t) > 0){
                extendible[i] = true;
            }

            claimables[i] = mineManagers[i].getDrawable(msg.sender,time);
        }

        return (lockAmounts,drawedEarnings,times,claimables,unLockables,extendible);
    }

    function getLockAmounts(address[] calldata owners) external view returns(uint[] memory values){

        values = new uint[](owners.length);

        for( uint i = 0; i < owners.length; i++){
            values[i] = miners[owners[i]].value;
        }
    }

    function getAwardInfo() external view returns(uint totalLock,uint totalAward,uint[] memory awards){

        Miner storage miner = miners[msg.sender];

        uint todayZero = timestemp() / 1 days * 1 days;

        awards = new uint[](lockInfos.length);

        for( uint i = 0; i < lockInfos.length; i++){

            uint value = mineManagers[i].getDrawable(msg.sender,todayZero);

            totalLock += miner.freezeManagers[i].total;

            totalAward += value;
            awards[i] = value;
        }
    }

    function getFinesInfo() external view returns(uint month,uint quarter,uint year){
        uint time = timestempZero();
        
        month = mineManagers[uint(Pool.MonthPool)].bestMatchIntervalValueReset(time);
        quarter = mineManagers[uint(Pool.QuarterPool)].bestMatchIntervalValueReset(time);
        year = mineManagers[uint(Pool.YearPool)].bestMatchIntervalValueReset(time);
    }

    
///////////////////////////////////////write/////////////////////////
///////////////////////////////////////write/////////////////////////


    
    function doAddLockOnePeriod(uint lock) external returns(bool){

        require( lockInfos.length > lock,"params_error");
        
        LockInfo storage info = lockInfos[lock];

        uint todayZero = timestempZero();

        (bool lockable,uint endTime) = _checkHasLockable(info,todayZero);
        require( lockable,"no_lockable");

        Miner storage miner = miners[msg.sender];
        
        uint value = miner.freezeManagers[lock].prolongFreeze(endTime,endTime+ info.period);

        if( value > 0 ){
            mineManagers[lock].changeData(msg.sender,value,todayZero);
        }

        return true;
    }

    function _checkHasLockable(LockInfo storage info,uint zeroTime)internal view returns(bool lockable,uint endTime){

        uint period = (zeroTime - info.startTime) / info.period;

        uint startTime = info.startTime + period * info.period;
        uint sealTime = info.sealTime + period * info.period;

        lockable = zeroTime >= startTime && zeroTime < sealTime;

        if( lockable){
            endTime = sealTime;
        }else{
            endTime = sealTime + info.period;
        }
    }

    function doLock(uint lock,uint amount) external returns(bool) {
        
        require(isStart && amount > 0 && lockInfos.length > lock,"params_error" );
        
        LockInfo storage info = lockInfos[lock];

        uint today = timestempZero();

        (bool lockable,uint endTime) = _checkHasLockable(info,today);
        require(lockable,"no_lockable");

        mineManagers[lock].changeData(msg.sender,amount,today);

        info.lockAmounts += amount;

        Miner storage miner = miners[msg.sender];
        miner.freezeManagers[lock].freeze(amount,endTime + info.period);
        miner.value += ( amount * lockAmountMultiples[lock] );

        powerMine.changePower(msg.sender,amount * 2,true);

        mineToken.transferFrom(msg.sender,address(this),amount);
        return true;
    }

    function doUnLock(uint lock) external KRejectContractCall returns(bool){
        
        uint todayZero = timestempZero();

        Miner storage miner = miners[msg.sender];

        uint value = miner.freezeManagers[lock].unFreeze(todayZero);

        if( value  > 0 ){
            powerMine.changePower(msg.sender,value * 2,false);

            uint lockAmounts = lockInfos[lock].lockAmounts;
            require( lockAmounts >= value,"amount_lock");
            lockInfos[lock].lockAmounts = ( lockAmounts - value);

            uint multiples = value * lockAmountMultiples[lock];
            uint lockValue = miner.value;
            require(lockValue >= multiples,"value_lock");
            miner.value = (lockValue - multiples);

            mineToken.transfer(msg.sender,value);
        }
        return true;
    }
      

    function doDraw() external KRejectContractCall returns (bool) {        

        Miner storage miner = miners[msg.sender];

        uint todayZero = timestempZero();

        uint award = 0;
        uint len = lockInfos.length;

        for( uint i = 0; i < len; i++){

            uint value = mineManagers[i].drawAward(msg.sender,todayZero);

            if( value > 0 ){
                miner.mineds[i] += value;
                award += value;
            }
        }

        if( award > 0 ){
            mineToken.transfer(msg.sender,award);
        }
        return true;
    }

    function injectFines(uint amount)external KDelegateMethod returns(bool){

        uint time = timestempZero();

        uint len = lockInfos.length;

        for( uint i = 0; i < len; i++){

            uint v = allotFinesConfig[i] * amount / 100;

            mineManagers[i].changeEveryIntervalReset(v,time);

        }
        return true;
    }


    

}


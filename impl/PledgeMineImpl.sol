// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

import "./k_noUpgradeable.sol";
import "./IERC20.sol";
import "./iRelation.sol";
import "./iPowerMine.sol";
import "./iLockMine.sol";
import "./TimeLineValuePledge.sol";
import "./TimeLineValueFreeze.sol";


contract PledgeMineStorage is KOwnerable {

    enum Pool{
        MonthPool,
        QuarterPool,
        YearPool,
        PowerPool
    }

    using TimeLineValuePledge for TimeLineValuePledge.Data;
    using TimeLineValueFreeze for TimeLineValueFreeze.Data;

    struct PledgeInfo{
        address pledgeCoin;
        uint pledgeAmount;
        bool isPropagatePower;
        bool isAirDrop;
        bool isLp;
    }

    PledgeInfo[] internal pledgeInfos;

    mapping(uint => TimeLineValuePledge.Data) internal mineManagers;

    struct Miner{
        mapping(uint => TimeLineValueFreeze.Data) freezeManagers;
    }

    mapping(address => Miner) internal miners;


    iRelation internal relation;

    struct ClaimCondition{
        uint lockTimes;
        uint punishRate;
        uint acquireRate;
    }

    ClaimCondition[] internal claimConditions;

    iPowerMine internal powerMine;
    iLockMine internal lockMine;
    iERC20 internal mineToken;

    uint[] internal finesAllotConfig = [70,30];

    uint internal airDropTotalAmount = 20000e18;
    uint internal airDropAmount = 10e18;
    uint internal shareAirDropTotalAmount = 10000e18;
    uint internal shareAirDropAmount = 5e18;

    mapping(address => bool) internal hasAirDrops;
    mapping(address => uint) internal airDrops;

    uint internal airDropCondition = 1e18;

    bool public isStart = false;
}

contract PledgeMine  is PledgeMineStorage {

    constructor(
        iRelation _relation,
        iERC20 _mineToken,
        iPowerMine _powerMine,
        iLockMine _lockMine
        )public {

        relation = _relation;
        mineToken = _mineToken;
        powerMine = _powerMine;
        lockMine = _lockMine;

        claimConditions.push(ClaimCondition(0,40,60));
        claimConditions.push(ClaimCondition(7 * 86400,30,70));
        claimConditions.push(ClaimCondition(15 * 86400,10,90));
    }
///////////////////////////////manage////////////////////
///////////////////////////////manage////////////////////

    function mStartPledgeMine()external KOwnerOnly returns(bool){
        isStart = true;
        return true;
    }

    function mSetMinedEveryDay(uint pledge,uint everyDay,bool isAdd)external KOwnerOnly returns(bool){
        if( everyDay > 0 ){
            mineManagers[pledge].changeEveryInterval( everyDay,timestemp(),isAdd);
        }
        return true;
    }

    function mGetMinedEveryDay(uint pledge)external view KOwnerOnly returns(uint v){
        v = mineManagers[pledge].intervalValueLastValue();
    }

    function addPledge(
        address pledgeCoin,
        uint everyDay,
        bool isPropagatePower,
        bool isAirDrop,
        bool isLP)external KOwnerOnly returns(bool){

        pledgeInfos.push(
            PledgeInfo(
                pledgeCoin,
                0,
                isPropagatePower,
                isAirDrop,
                isLP)
                );

        mineManagers[pledgeInfos.length-1].initNetwork(1 days,15);

        mineManagers[pledgeInfos.length-1].changeEveryInterval( everyDay,timestempZero(),true);
        return true;
    }


///////////////////////////////read////////////////////
///////////////////////////////read////////////////////


    function getFinesInfo() external view returns(uint[] memory finesAmounts){

        finesAmounts = new uint[](4);

        (
            finesAmounts[uint(Pool.MonthPool)],
            finesAmounts[uint(Pool.QuarterPool)],
            finesAmounts[uint(Pool.YearPool)]) = lockMine.getFinesInfo();

        finesAmounts[uint(Pool.PowerPool)] = powerMine.getFinesInfo();
    }

 
    function getClaimConditions()external view returns(
        uint[] memory lockDays,
        uint[] memory punishRates,
        uint[] memory acquireRates){

            uint len = claimConditions.length;
            lockDays = new uint[](len);
            punishRates = new uint[](len);
            acquireRates = new uint[](len);

            for( uint i = 0; i < len; i++){
                ClaimCondition storage condition = claimConditions[i];
                lockDays[i] = condition.lockTimes;
                punishRates[i] = condition.punishRate;
                acquireRates[i] = condition.acquireRate;
            }
            return(lockDays,punishRates,acquireRates);
    }

    function getPledgeInfo()external view returns(uint[] memory totalAmounts,uint[] memory apys){

        totalAmounts = new uint[](pledgeInfos.length);
        apys = new uint[](pledgeInfos.length);

        for( uint i = 0; i < pledgeInfos.length; i++){
            PledgeInfo storage pledge = pledgeInfos[i];
            totalAmounts[i] = pledge.pledgeAmount;
            (apys[i],) = _getApyAndTvl(i,pledge);
        }
        return (totalAmounts,apys);
    }

    function _getApyAndTvl(uint index,PledgeInfo storage pledge)internal view returns(uint apy,uint tvl){

        uint denominator = pledge.pledgeAmount;

        uint base = mineManagers[index].intervalValueLastValue()  * 365;

        if( denominator == 0 ){
            return (base / 1e18 ,0);
        }else{
            return (base / denominator, denominator);
        }
    }    

    function getMyInfos()external view returns(
        uint[]memory amounts,
        uint[] memory apys,
        uint[] memory tvls){

        uint len = pledgeInfos.length;
        amounts = new uint[](len);
        apys = new uint[](len);
        tvls = new uint[](len);

        for( uint i = 0; i < len; i++){
            (apys[i],tvls[i]) = _getApyAndTvl(i,pledgeInfos[i]);
            amounts[i] = mineManagers[i].personalLastValue(msg.sender);
        }
        return (amounts,apys,tvls);
    }

    function freezeable(uint pledge) external view returns(uint){

        require(pledge < pledgeInfos.length,"exceed");

        uint time = timestemp() / 1 days * 1 days;

        uint v = mineManagers[pledge].getDrawable(msg.sender,time);
        return v;
    }


    function getAwardInfo()external view returns(uint totalFreeze,uint totalAward,uint[] memory awards){
        uint256 time = timestempZero();

        Miner storage miner = miners[msg.sender];

        awards = new uint[](pledgeInfos.length);

        for( uint i = 0; i < pledgeInfos.length; i++ ){

            totalFreeze += miner.freezeManagers[i].total;

            uint v =  miner.freezeManagers[i].getUnFreezeable(time);

            totalAward += v;
            awards[i] = v;
        }
        return (totalFreeze,totalAward,awards); 
    }


/////////////////////////////write////////////////////////////
/////////////////////////////write////////////////////////////

    function doClaimAirDrop(address owner)external  KDelegateMethod returns(uint){

        if( airDrops[owner] > 0 ){
            uint amount = airDrops[owner];
            airDrops[owner] = 0;
            return amount;
        }
        return 0;
    }


    function doPledge(uint pledge,uint amount)external payable KRejectContractCall returns(bool){

        require( isStart && amount > 0 && pledgeInfos.length > pledge ,"params_error");

        PledgeInfo storage pledgeInfo = pledgeInfos[pledge];

        address pledgeCoin = pledgeInfo.pledgeCoin;
        if( pledgeCoin != address(0) ){

            iERC20(pledgeCoin).transferFrom(msg.sender,address(this),amount);
        }else{
            require(msg.value >= amount,"not_main_or_value_lock");
        }

        _todoPledge(msg.sender,pledgeInfo,pledge,amount,true);

        if( pledgeInfo.isAirDrop && amount >= airDropCondition && !hasAirDrops[msg.sender] ){

            hasAirDrops[msg.sender] = true;

            uint _airDropTotalAmount = airDropTotalAmount;
            uint _airDropAmount = airDropAmount;
            if( _airDropTotalAmount >= _airDropAmount ){
                _airDropTotalAmount -= _airDropAmount;
                airDrops[msg.sender] += _airDropAmount;
                airDropTotalAmount = _airDropTotalAmount;
            }
            

            uint _shareAirDropTotalAmount = shareAirDropTotalAmount;
            uint _shareAirDropAmount = shareAirDropAmount;
            if( _shareAirDropTotalAmount >= _shareAirDropAmount){
                address parent = relation.getRecommer(msg.sender);
                if( parent != address(0x0)){
                    _shareAirDropTotalAmount -= _shareAirDropAmount;
                    airDrops[parent] += _shareAirDropAmount;
                    shareAirDropTotalAmount = _shareAirDropTotalAmount;
                }
            }
        }
        return true;
    }


    function doUnPledge(uint pledge,uint amount) external KRejectContractCall returns(bool){

        require(amount > 0 && pledgeInfos.length > pledge ,"params_error");

        PledgeInfo storage pledgeInfo = pledgeInfos[pledge];

        _todoPledge(msg.sender,pledgeInfo,pledge,amount,false);

        address pledgeCoin = pledgeInfo.pledgeCoin;
        if( pledgeCoin == address(0)){
            msg.sender.transfer(amount);
        }else{
            iERC20(pledgeCoin).transfer(msg.sender,amount);
        }
        return true;
    }


    function _todoPledge(address owner,PledgeInfo storage pledgeInfo,uint pledge,uint amount,bool isAdd) internal{
        
        uint curMin = timestemp() / 1 minutes * 1 minutes;

        mineManagers[pledge].changeData(owner,amount,curMin,isAdd);
    
        uint pledgeAmount = pledgeInfo.pledgeAmount;
        if( isAdd){
            pledgeAmount += amount;
        }else{
            require(pledgeAmount >= amount,"amount_lock");
            pledgeAmount -= amount;
        }
        pledgeInfo.pledgeAmount = pledgeAmount;

        if( pledgeInfo.isPropagatePower){
            powerMine.changePower(owner,amount,isAdd);
        }
    }


    function doFreeze(uint pledge,uint finesLevel) external  returns (bool) {  

        require(pledgeInfos.length > pledge && claimConditions.length > finesLevel,"params_error");

        Miner storage miner = miners[msg.sender];

        uint256 todayZero = timestempZero();

        uint v  = mineManagers[pledge].drawAward(msg.sender,todayZero);

        if( v > 0 ){

            ClaimCondition storage cc = claimConditions[finesLevel];

            uint acquireAmount = v * cc.acquireRate / 100;            
            
            uint lockTimes = cc.lockTimes;
            if(lockTimes > 0){
                miner.freezeManagers[pledge].freeze(acquireAmount,todayZero + lockTimes);
            }else{
                mineToken.transfer(msg.sender,acquireAmount);
            }

            uint fineAmount = v * cc.punishRate / 100;
            if( fineAmount > 0 ){
                lockMine.injectFines(fineAmount * finesAllotConfig[0] / 100);
                powerMine.injectFines(fineAmount * finesAllotConfig[1] / 100);
            }    
        }
        return true;
    }

    function doDraw() external KRejectContractCall returns(bool){

        uint256 time = timestempZero();

        Miner storage miner = miners[msg.sender];

        uint totalAward  = 0;
        uint len = pledgeInfos.length;
        for( uint i = 0; i < len; i++ ){
            uint v =  miner.freezeManagers[i].unFreeze(time);
            totalAward += v;
        }

        if( totalAward > 0){
            mineToken.transfer(msg.sender,totalAward);
        }
        return true; 
    }
    
    function () external payable {}
}


// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;


library TimeLineValueLock {

    struct Value{
        uint[] keys;
        mapping(uint => uint) values;
    }

    struct Data {
        uint initTime;
        uint sealTime;
        uint interver;
        uint depth;
        mapping(uint => uint) networkValues;
        mapping(address => mapping(uint => uint)) personalValues;
        mapping(address => uint) ownerLastDrawTime;
        mapping(uint => uint) everyIntervalValues;
        mapping(uint => uint) everyIntervalValueReset;
    }


    function initNetwork(Data storage self,uint interver,uint initTime,uint sealTime,uint depth) internal {
        self.interver = interver;
        self.initTime = initTime;
        self.sealTime = sealTime;
        self.depth = depth;
    }


    function changeEveryInterval(Data storage self, uint value, uint time) internal{
        uint period = (time - self.initTime) / self.interver;
        for(uint i = 0; i < 6; i++){
            self.everyIntervalValues[period+i] = value;
        }
    }

    function changeEveryIntervalReset(Data storage self,uint value, uint todayZero) internal  {
        self.everyIntervalValueReset[todayZero] += value;
    }


    function changeData(Data storage self,address owner, uint value, uint todayZero)internal{

        uint period = (todayZero - self.initTime) / self.interver;

        if( self.ownerLastDrawTime[owner] == 0 ){
            self.ownerLastDrawTime[owner] = self.sealTime + period * self.interver;
        }
        self.personalValues[owner][period] += value;

        self.networkValues[period] += value;
    }


    function _settle(Data storage self,address owner,uint todayZero,uint lastZero) internal  view returns(uint v) {

        uint startTime = todayZero - 1 days;

        for( uint index = self.depth; startTime >= lastZero && index > 0; (startTime -= 1 days,index--) ){

            uint period = (startTime - self.sealTime) / self.interver;

            uint numerator = self.personalValues[owner][period];
            uint denominator = self.networkValues[period];

            uint everyIntervalValue = self.everyIntervalValues[period] + self.everyIntervalValueReset[startTime];

            if( denominator > 0 && numerator <=  denominator){

                v += numerator * everyIntervalValue / denominator;
            }

        }
    }



    function getDrawable(Data storage self, address owner,uint todayZero)internal view returns(uint v){

        uint lastZero = self.ownerLastDrawTime[owner];

        if( lastZero != 0 && todayZero > lastZero ){
            v = _settle(self,owner,todayZero,lastZero);
        }
    }


    function drawAward(Data storage self, address owner,uint todayZero)internal returns(uint v){
        
        uint lastZero = self.ownerLastDrawTime[owner];

        if( lastZero != 0 && todayZero > lastZero ){
            v = _settle(self,owner,todayZero,lastZero);
            self.ownerLastDrawTime[owner] = todayZero;
        }
        return v;
    }

    function intervalValueLastValue(Data storage self,uint todayZero)internal view returns(uint){
        uint period = (todayZero - self.initTime) / self.interver;
        return self.everyIntervalValues[period] + self.everyIntervalValueReset[todayZero];
    }

    function lastValue(Data storage self,uint todayZero)internal view returns(uint){
        uint period = (todayZero - self.initTime) / self.interver;
        return self.everyIntervalValues[period];
    }


    function bestMatchIntervalValueReset(Data storage self,uint todayZero)internal view returns(uint){
        return self.everyIntervalValueReset[todayZero];
    }


    function _latestValue(Value storage self) internal view returns (uint) {
        if ( self.keys.length == 0 ) {
            return 0;
        }
        uint time = self.keys[self.keys.length-1];
        return self.values[time];
    }

}

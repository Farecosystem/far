// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;


library TimeLineValuePower {

    struct Value{
        uint[] timeList;
        mapping(uint => uint) valueMapping;
    }

    struct Data {
        uint depth;
        uint timeInterval;
        Value networkValues;
        mapping(address =>Value) personalValues;
        mapping(address => uint) ownerLastDrawTime;
        Value everyIntervalValues;
        mapping(uint => uint) everyIntervalValueReset;
    }

    
    function initNetwork(Data storage self,uint timeInterval,uint depth) internal {
        self.timeInterval = timeInterval;
        self.depth = depth;
    }

    function changeEveryInterval(Data storage self, uint value, uint time,bool isAdd) internal{
        if( isAdd){
            _increase(self.everyIntervalValues, value, time);
        }else{
            _decrease(self.everyIntervalValues, value, time);
        }
    }


    function changeEveryIntervalReset(Data storage self,uint value, uint time) internal  {
        self.everyIntervalValueReset[time] += value;
    }

    function addDatas(Data storage self,address[] memory owners, uint amount, uint todayZero)internal {

        uint total = 0;

        uint len = owners.length;
        for( uint i = 0; i < len; i++ ){
            address owner = owners[i];
            if( owner != address(0) ){

                if( self.ownerLastDrawTime[owner] == 0 ){
                    self.ownerLastDrawTime[owner] = todayZero;
                }

                total += amount;
                _increase(self.personalValues[owner], amount, todayZero); 
            }
        }

        if( total > 0 ){
            _increase(self.networkValues, total, todayZero);
        }
    }


    function subDatas(Data storage self,address[] memory owners, uint[] memory values, uint todayZero)internal {

        uint total = 0;

        uint len = values.length;
        for( uint i = 0; i < len; i++ ){

            if( values[i] > 0 ){
                total += values[i];
                _decrease(self.personalValues[owners[i]], values[i], todayZero);
            }
        }

        if( total > 0 ){
            _decrease(self.networkValues, total, todayZero);  
        }
    }


    function _settle(Data storage self, address owner,uint todayZero,uint lastZero)internal view returns(uint v){
                
        uint startTime = todayZero - 1 days;

        for( uint index = self.depth ; startTime >= lastZero && index > 0; (startTime -= 1 days,index--)){

            uint numerator = _bestMatchValue(self.personalValues[owner],startTime,self.depth);

            uint denominator = _bestMatchValue(self.networkValues,startTime,self.depth);

            uint everyIntervalValue = _bestMatchValue(self.everyIntervalValues,startTime,self.depth) + self.everyIntervalValueReset[startTime];

            if( denominator > 0 && numerator <= denominator ){
                v += numerator * everyIntervalValue / denominator;
            }
        }
    }

    function drawAward(Data storage self, address owner,uint todayZero)internal returns(uint v){

        uint lastZero = self.ownerLastDrawTime[owner];

         if( lastZero == 0 || lastZero >= todayZero) return 0;

        v = _settle(self,owner,todayZero,lastZero);

        self.ownerLastDrawTime[owner] = todayZero;

        return v;
    }



    function networkLastvalue(Data storage self)internal view returns(uint){

        return _latestValue(self.networkValues);
    }

    function personalLastValue(Data storage self,address owner)internal view returns(uint){
        return (_latestValue(self.personalValues[owner]));
    }

    function intervalValueLastValue(Data storage self)internal view returns(uint){
        return _latestValue(self.everyIntervalValues);
    }

    function bestMatchIntervalValueReset(Data storage self,uint time)internal view returns(uint){
        return self.everyIntervalValueReset[time];
    }

    function _increase(Value storage self, uint addValue, uint time) internal{

        if( self.timeList.length == 0 ){
            self.timeList.push(time);
            self.valueMapping[time] = addValue;
        }else{
            uint latestTime = self.timeList[self.timeList.length - 1];

            if (latestTime == time) {
                self.valueMapping[latestTime] += addValue;
            }else{
                self.timeList.push(time);
                self.valueMapping[time] = (self.valueMapping[latestTime] + addValue);
            }
        }
    }

    function _decrease(Value storage self, uint subValue, uint time) internal{

        if( self.timeList.length != 0 ){
            uint latestTime = self.timeList[self.timeList.length - 1];

            require(self.valueMapping[latestTime] >= subValue, "InsufficientQuota");

            if (latestTime == time) {
                self.valueMapping[latestTime] -= subValue;
            } else {
                self.timeList.push(time);
                self.valueMapping[time] = ( self.valueMapping[latestTime] - subValue);
            }
        }
    }


    function _latestValue(Value storage self) internal view returns (uint) {
        uint[] storage s = self.timeList;
        if ( s.length <= 0 ) {
            return 0;
        }

        uint time = self.timeList[s.length-1];
        return self.valueMapping[time];
    }

    function _bestMatchValue(Value storage self,uint time,uint depth) internal view returns(uint) {

        uint[] storage s = self.timeList;

        if (s.length == 0 || time < s[0]) {
            return 0;
        }

        for( 
            (uint i,uint d) = (s.length,0); 
            i > 0 && d < depth; 
            ( i--,d++)){

            if( time >= s[i-1] ){
                return  self.valueMapping[s[i-1]];
            }
        }
        return 0;
    }


}

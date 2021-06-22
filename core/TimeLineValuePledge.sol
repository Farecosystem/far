// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;


library TimeLineValuePledge {

    struct Value{
        uint[] timeList;
        mapping(uint => uint) valueMapping;
    }

    struct Data {
        uint interval;
        uint depth;
        Value minedDayLine; 

        mapping(address => Value) personDayInvestLine;
        mapping(address => mapping(uint => uint)) personDayValidLine;

        Value investDayLine;
        mapping(uint => uint) validDayLine;

        mapping(address => uint) lastDrawTime;
    }


    function initNetwork(Data storage self,uint interval,uint depth)internal{
        self.interval = interval;
        self.depth = depth;
    }


    function changeEveryInterval(Data storage self, uint value,uint time,bool isAdd) internal{
        if( isAdd){
            _increase(self.minedDayLine, value, time);
        }else{
            _decrease(self.minedDayLine, value, time);
        }
    }


    function changeData(Data storage self,address owner, uint value, uint time,bool isAdd)internal{

        uint today = time / self.interval * self.interval;

        if( self.personDayInvestLine[owner].timeList.length == 0 ){
            self.lastDrawTime[owner] = today;
        }

        uint lastValue = 0;
        uint networkLastValue = 0;

        if( isAdd ){
            lastValue = _increase(self.personDayInvestLine[owner], value, today);
            networkLastValue = _increase(self.investDayLine, value, today);
        }else{
            lastValue = _decrease(self.personDayInvestLine[owner], value, today);
            networkLastValue = _decrease(self.investDayLine, value, today);
        }

        uint personValue = self.personDayValidLine[owner][today];
        uint networkValue = self.validDayLine[today];

        if( lastValue > 0 ){
            personValue += lastValue * 1440;
        }

        if( networkLastValue > 0 ){
            networkValue += networkLastValue * 1440;
        }

        uint validMin = (today + 1 days - time)  * value / 60;

        if(isAdd){
            personValue += validMin;
            networkValue += validMin;
        }else{
            require(personValue >= validMin,"p_value_lock");
            personValue -= validMin;
            
            require(networkValue >= validMin,"n_value_lock");
            networkValue -= validMin;
        }

        self.personDayValidLine[owner][today] = personValue;
        self.validDayLine[today] = networkValue;

    }



    function drawAward(Data storage self, address owner,uint todayZero)internal returns(uint v){

        uint lastDrawTime = self.lastDrawTime[owner];

        if( lastDrawTime != 0 && lastDrawTime < todayZero ){
            v = _calculateAward(self,owner,lastDrawTime,todayZero);
            self.lastDrawTime[owner] = todayZero;
        }        
        return v;
    }

    function getDrawable(Data storage self, address owner,uint todayZero)internal view returns(uint v){

        uint lastDrawTime = self.lastDrawTime[owner];

        if( lastDrawTime != 0 && lastDrawTime < todayZero ){
            v = _calculateAward(self,owner,lastDrawTime,todayZero);
        }        
        return v;
    }

    function _calculateAward(Data storage self, address owner,uint lastZero,uint todayZero)internal view returns(uint v){

        uint startTime = todayZero - 1 days;      

        for(uint index = self.depth ; startTime >= lastZero && index > 0 ; (startTime -= 1 days,index--)){

            uint numerator = self.personDayValidLine[owner][startTime];
            if( numerator == 0 ){
                uint hold = _bestMatchValue(self.personDayInvestLine[owner], startTime, self.depth);
                numerator = hold * 1440;
            }
            
            uint denominator = self.validDayLine[startTime];
            if( denominator == 0 ){
                uint hold = _bestMatchValue(self.investDayLine, startTime, self.depth);
                denominator = hold * 1440;
            }

            uint mined = _bestMatchValue(self.minedDayLine, startTime, self.depth);

            if( denominator > 0 && numerator <= denominator){

                v += numerator * mined / denominator;
            }
        }
    }


    function networkLastvalue(Data storage self)internal view returns(uint v){
        v = _latestValue(self.investDayLine);
    }

    function personalLastValue(Data storage self,address owner)internal view returns(uint v){
        v = _latestValue(self.personDayInvestLine[owner]);
    }

    function intervalValueLastValue(Data storage self)internal view returns(uint v){

        v = _latestValue(self.minedDayLine);
        return v;
    }


    function _increase(Value storage self, uint addValue, uint time) internal returns(uint){

        uint[] storage timeList  = self.timeList;

        if( timeList.length == 0 ){
            timeList.push(time);
            self.valueMapping[time] = addValue;
            return 0;
        }else{
            uint latestTime = timeList[timeList.length - 1];

            if (latestTime == time) {
                self.valueMapping[latestTime] += addValue;
                return 0;
            }else{
                uint v = self.valueMapping[latestTime];
                timeList.push(time);
                self.valueMapping[time] = (v + addValue);
                return v;
            }
        }
    }

    function _decrease(Value storage self, uint subValue, uint time) internal returns(uint){

        uint[] storage timeList  = self.timeList;

        if( timeList.length != 0 ){

            uint latestTime = timeList[timeList.length - 1];

            uint v = self.valueMapping[latestTime];
            require(v >= subValue, "InsufficientQuota");

            if (latestTime == time) {
                v -= subValue;
                self.valueMapping[latestTime] = v;
                return 0;
            } else {
                timeList.push(time);
                self.valueMapping[time] = ( v - subValue);
                return v;
            }
        }
        return 0;
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

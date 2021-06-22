// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;


library TimeLineValueFreeze {

    struct Data {
        uint total;
        uint unLockIndex;
        uint[] timeList;
        mapping(uint => uint) valueMapping;
    }

    function freeze(Data storage self, uint value, uint zeroTime) internal{

        if( self.timeList.length == 0 
            || zeroTime !=  self.timeList[self.timeList.length - 1]){

            self.timeList.push(zeroTime);
        }
        
        self.valueMapping[zeroTime] += value;
        self.total += value;
    }
    
    function prolongFreeze(Data storage self, uint unFreezeTime,uint prolongTime) internal returns(uint){
        
        require(prolongTime > unFreezeTime,"params_error");
        uint v = unFreeze(self, unFreezeTime);

        if( v > 0 ){
            freeze(self, v, prolongTime);
        }
        return v;
    }

    function getUnFreezeable(Data storage self, uint time) internal view returns(uint v){

        if( self.timeList.length == 0 ) return 0;

        uint i = self.unLockIndex;

        for( ; i < self.timeList.length; i++){
            uint t = self.timeList[i];
            if( t > time){
                break;
            }
            v += self.valueMapping[t];
        }
    }

    function unFreeze(Data storage self, uint zeroTime) internal returns(uint v) {
        
        uint i = self.unLockIndex;

        uint len = self.timeList.length;
        for( ; i < len; i++){
            
            uint t = self.timeList[i];
            if( t > zeroTime){
                break;
            }

            v += self.valueMapping[t];
            self.valueMapping[t] = 0;
        }
        if( v > 0 ){
            require(self.total >= v,"value_lock");
            self.total -= v;
        }
        self.unLockIndex = i;
    }

    function getFreezeInfos(Data storage self,uint pageIndex,uint size)internal view returns(uint total,uint[] memory amounts,uint[] memory times){

        total = self.timeList.length - self.unLockIndex;

        if( total > 0 ){

            uint pages = total / size;
            if( total % size > 0 ){
                pages += 1;
            }

            uint start = self.unLockIndex + (pageIndex -1) * size;

            uint end = start;
            if( pageIndex == pages ){
                end = self.timeList.length - 1;
            }else{
                end = start + size -1;
            }

            if( end >= start ){
                uint len = end - start + 1;
                amounts = new uint[](len);
                times = new uint[](len);

                for( uint index = 0; start <= end; (start++,index++)){
                    times[index] = self.timeList[start];
                    amounts[index] = self.valueMapping[times[index]];
                }
                return (total,amounts,times);
            }
        }
    }
}

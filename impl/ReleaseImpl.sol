// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

import "./k_noUpgradeable.sol";
import "./IERC20.sol";
import "./iPledgeMine.sol";



contract ReleaseStorage is KOwnerable {

    iERC20 internal token;

    struct UserData{
        uint totalAmount;
        uint drawed;
        uint lastDrawIndex;
        AirDrop[] airs;
    }
    struct AirDrop{
        uint initTime;
        uint lastDrawTime;
        uint amount;
        uint drawed;
    }


    mapping(address => UserData) internal userDatas;

    mapping(address => bool) internal hasImport;
    
    uint internal releaseRate = 0.001e6;

    iPledgeMine internal pledgeMine;   

    bool internal isStart;
}

contract Release is ReleaseStorage {
     
     constructor(iERC20 _token,iPledgeMine _pledgeMine) public{
        pledgeMine = _pledgeMine;
        token = _token;
    }
///////////////////////////manage/////////////////////////////
///////////////////////////manage/////////////////////////////

    function mStartAirDrop(bool _isStart)external returns(bool){
        isStart = _isStart;
        return true;
    }

    function importUser(address[] calldata owners,uint[] calldata values)external KOwnerOnly returns(bool){

        require(owners.length == values.length,"len_error");

        uint todayZero = timestempZero();

        for( uint i = 0; i < owners.length; i++){
            if( !hasImport[owners[i]] && owners[i] != address(0) && values[i] > 0 ){
                hasImport[owners[i]] = true;
                _addOneAirDrop( owners[i],values[i],todayZero);
            }
        }
        
    }

///////////////////////////read/////////////////////////////
///////////////////////////read/////////////////////////////

    function myInfo() external view returns(uint freezeA,uint drawdA){

        UserData storage data = userDatas[msg.sender];
        freezeA = data.totalAmount;
        drawdA = data.drawed;
    }


///////////////////////////write/////////////////////////////
///////////////////////////write/////////////////////////////


    function claimAirDrop()external returns(uint v){
        require(isStart);
        v = pledgeMine.doClaimAirDrop(msg.sender);

        if( v > 0 ){
            _addOneAirDrop(msg.sender,v,timestempZero());
        }
        return v;
    }

    function _calulateRelease(UserData storage user,uint todayZero)internal returns(uint v){

        AirDrop[] storage airs = user.airs;

        uint index = user.lastDrawIndex;

        for( uint depth = 0; index < airs.length && depth < 10; (index++,depth++) ){

            AirDrop storage air = airs[index];

            if( air.lastDrawTime >= todayZero) break;

            uint drawed = air.drawed;
            uint amount = air.amount;

            if( drawed >= amount ){
                user.lastDrawIndex = index + 1;
                continue;
            }

            uint dayNum =  ( todayZero - air.lastDrawTime) / 1 days;

            uint award = dayNum * amount * releaseRate / 1e6;

            if( award + drawed > amount ){
                award = amount - drawed;
            }
            v += award;
            drawed += award;

            air.drawed = drawed;
            air.lastDrawTime = todayZero;
        }
    }

    function drawRelease() external KRejectContractCall returns(uint v){

        UserData storage data = userDatas[msg.sender];

        uint totalAmount = data.totalAmount;
        uint drawed =  data.drawed;

        if( totalAmount <= drawed ) return 0;

        v = _calulateRelease( data , timestempZero());

        if(v == 0 ) return 0;

        if( v + drawed > totalAmount ){
            v = totalAmount - drawed;
        }
        drawed += v;

        data.drawed = drawed;
    
        token.transfer(msg.sender, v);
        return v;
    }

    function _addOneAirDrop(address owner,uint amount,uint todayZero)internal {

        UserData storage data = userDatas[owner];

        uint len = data.airs.length;
        if(len == 0 ){
            data.airs.push( AirDrop(todayZero,todayZero,amount,0));
        }else{

            AirDrop storage last = data.airs[len-1];

            if( last.initTime == todayZero ){
                last.amount += amount;
            }else{
                data.airs.push( AirDrop(todayZero,todayZero,amount,0));
            }
        }
        data.totalAmount += amount;
    }




}
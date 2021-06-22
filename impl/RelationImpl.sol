// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

import "./k_noUpgradeable.sol";


contract RelationStorage is KOwnerable {

    address internal rootAddress = address(0xdeadad);

    uint public totalAddresses;

    mapping (address => address payable) internal _recommerMapping;

    mapping (address => address[]) internal _recommerList;

    mapping (bytes8 => address) internal _shortCodeMapping;

    mapping (address => bytes8) internal _addressShotCodeMapping;

    mapping(address => uint) tiers;
}

contract Relation is RelationStorage{

    constructor() public {
        _shortCodeMapping[0x3058444541444144] = rootAddress;
        _addressShotCodeMapping[rootAddress] = 0x3058444541444144;
        _recommerMapping[rootAddress] = address(0xdeaddead);
    }

    function recommendInfo() external view returns(
        bytes8 shotCode,
        bytes8 recommerShotCode){

        shotCode = _addressShotCodeMapping[msg.sender];
        recommerShotCode = _addressShotCodeMapping[_recommerMapping[msg.sender]];
        return(shotCode,recommerShotCode);
    }

    function shortCodeToAddress(bytes8 shortCode) external view returns (address) {
        return _shortCodeMapping[shortCode];
    }

    function addressToShortCode(address addr) external view returns (bytes8) {
        return _addressShotCodeMapping[addr];
    }


    function checkCodeIsExist(bytes8 code)external view returns(bool){
        return _shortCodeMapping[code] != address(0x0);
    }


    function addRelationEx(address recommer, bytes8 shortCode) external KRejectContractCall returns (bool) {

        require(shortCode != bytes8(0x0),"invalid_code");

        require(_shortCodeMapping[shortCode] == address(0x0),"code_exist");

        require(_addressShotCodeMapping[msg.sender] == bytes8(0x0),"has_code");

        require(recommer != msg.sender,"your_self");

        require(_recommerMapping[msg.sender] == address(0x0),"binded");

        require(recommer == rootAddress || _recommerMapping[recommer] != address(0x0),"p_not_bind");

        totalAddresses++;

        _shortCodeMapping[shortCode] = msg.sender;
        _addressShotCodeMapping[msg.sender] = shortCode;

        _recommerMapping[msg.sender] = address(uint160(recommer));
        _recommerList[recommer].push(msg.sender);
        
        tiers[msg.sender] = tiers[recommer] + 1;
        return true;
    }

    function getChilds(address owner)external view returns(address[] memory){
        return _recommerList[owner];
    }

    function getRecommer(address owner) external view returns(address){
        address recommer =  _recommerMapping[owner];
        if( recommer != rootAddress ) return recommer;
        return address(0x0);
    }

    function getRecommers(address owner,uint num)external view returns(address[] memory recommers){

        uint tier = tiers[owner];

        if( tier <= 1) return recommers;

        tier --;

        uint len = tier > num ? num : tier;

        recommers = new address[](len);

        address parent = owner;
        for( uint i = 0; i < len; i++){
            parent = _recommerMapping[parent];
            recommers[i] = parent;
        }
        return recommers;
    }


}

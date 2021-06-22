// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

interface iRelation{
    
    function getRecommers(address owner,uint num)external returns(address[] memory recommers);

    function addRelationEx(address recommer, bytes6 shortCode) external payable returns (bool);

    function getRecommer(address owner) external view returns(address);


}
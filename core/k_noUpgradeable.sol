// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.8.0;

contract KOwnerable {

    address[] internal _authAddress;

    address[] public KContractOwners;

    bool private _call_locked;

    constructor() public {
        KContractOwners.push(msg.sender);
        _authAddress.push(msg.sender);
    }

    function KAuthAddresses() external view returns (address[] memory) {
        return _authAddress;
    }

    
    function KAddAuthAddress(address auther) external KOwnerOnly {
        _authAddress.push(auther);
    }

    
    function KDelAuthAddress(address auther) external KOwnerOnly {
        for (uint i = 0; i < _authAddress.length; i++) {
            if (_authAddress[i] == auther) {
                for (uint j = 0; j < _authAddress.length - 1; j++) {
                    _authAddress[j] = _authAddress[j+1];
                }
                delete _authAddress[_authAddress.length - 1];
                _authAddress.pop();
                return ;
            }
        }
    }

    modifier KOwnerOnly() {
        bool exist = false;
        for ( uint i = 0; i < KContractOwners.length; i++ ) {
            if ( KContractOwners[i] == msg.sender ) {
                exist = true;
                break;
            }
        }
        require(exist, 'NotAuther'); _;
    }

    modifier KDemocracyOnly() {
        bool exist = false;
        for ( uint i = 0; i < KContractOwners.length; i++ ) {
            if ( KContractOwners[i] == msg.sender ) {
                exist = true;
                break;
            }
        }
        require( exist , 'NotAuther'); _;
    }

    modifier KOwnerOnlyAPI() {
        bool exist = false;
        for ( uint i = 0; i < KContractOwners.length; i++ ) {
            if ( KContractOwners[i] == msg.sender ) {
                exist = true;
                break;
            }
        }
        require(exist, 'NotAuther'); _;
    }

    modifier KRejectContractCall() {
        uint256 size;
        address payable safeAddr = msg.sender;
        assembly {size := extcodesize(safeAddr)}
        require( size == 0, "Sender Is Contract" );
        _;
    }

    modifier KDAODefense() {
        require(!_call_locked, "DAO_Warning");
        _call_locked = true;
        _;
        _call_locked = false;
    }

    modifier KDelegateMethod() {
        bool exist = false;
        for (uint i = 0; i < _authAddress.length; i++) {
            if ( _authAddress[i] == msg.sender ) {
                exist = true;
                break;
            }
        }
        require(exist, "PermissionDeny"); _;
    }

    function timestempZero() internal view returns (uint) {
        return timestemp() / 1 days * 1 days;
    }

    function timestemp() internal view returns (uint) {
        return now;
    } 


}


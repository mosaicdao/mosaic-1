pragma solidity >=0.5.0 <0.6.0;

// Copyright 2019 OpenST Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// ----------------------------------------------------------------------------
// Contracts: MockToken
//
// http://www.simpletoken.org/
//
// ----------------------------------------------------------------------------


import "./MockTokenConfig.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../../ERC20I.sol";


contract MockToken is ERC20I, MockTokenConfig {

    using SafeMath for uint256;

    string  private tokenName;
    string  private tokenSymbol;
    uint8   private tokenDecimals;
    uint256 internal tokenTotalSupply;

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;

    constructor(uint8 _decimals) public {
        uint256 decimalsFactor = 10**uint256(_decimals);
        uint256 tokensMax = 800000000 * decimalsFactor;

        tokenSymbol = TOKEN_SYMBOL;
        tokenName = TOKEN_NAME;
        tokenDecimals = _decimals;
        tokenTotalSupply = tokensMax;
        balances[msg.sender] = tokensMax;

        // According to the ERC20 standard, a token contract which creates new tokens should trigger
        // a Transfer event and transfers of 0 values must also fire the event.
        emit Transfer(address(0), msg.sender, tokensMax);
    }

    function name() public view returns (string memory) {
        return tokenName;
    }


    function symbol() public view returns (string memory) {
        return tokenSymbol;
    }


    function decimals() public view returns (uint8) {
        return tokenDecimals;
    }


    function totalSupply() public view returns (uint256) {
        return tokenTotalSupply;
    }


    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }


    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }


    function transfer(address _to, uint256 _value) public returns (bool success) {
        // According to the EIP20 spec, "transfers of 0 values MUST be treated as normal
        // transfers and fire the Transfer event".
        // Also, should throw if not enough balance. This is taken care of by SafeMath.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);

        return true;
    }


    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(_from, _to, _value);

        return true;
    }


    function approve(address _spender, uint256 _value) public returns (bool success) {

        allowed[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    /**
     * @notice It burns an amount of the token of a given
     *         account.
     * @param _account The account whose tokens will be burnt.
     * @param _value The amount that will be burnt.
     *
     * @return success `true` if tokens are burned successfully otherwise false
     */
    function burn(address _account, uint256 _value) public returns (bool success) {
        require(_account != address(0), "ERC20: burn from the zero address");

        tokenTotalSupply = tokenTotalSupply.sub(_value);
        balances[_account] = balances[_account].sub(_value);
        emit Transfer(_account, address(0), _value);
        success = true;
    }

    /**
     * @notice It helps to an amount of the tokens of a given account,
     *         deducting from the sender's allowance for said account. Uses the
     *         function burn.
     *         Emits an Approval event (reflecting the reduced allowance).
     * @param _account The account whose tokens will be burnt.
     * @param _value The amount that will be burnt.
     *
     * @return success `true` if tokens are burned successfully otherwise false
     */
    function burnFrom(address _account, uint256 _value) public returns (bool success) {
        allowed[_account][msg.sender] = allowed[_account][msg.sender].sub(
            _value
        );
        burn(_account, _value);
        emit Approval(_account, msg.sender, allowed[_account][msg.sender]);
        success = true;
    }
}

pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // owner => spender => allowance
  mapping (address => mapping (address => uint256)) internal allowances;

  // list of current non-zero token holders
  address[] internal holders;
  // holder => (index in `holders` + 1); 0 means "not in list"
  mapping (address => uint256) internal holderIndex;

  // accrued, withdrawable dividend (in wei) per address
  mapping (address => uint256) internal accruedDividend;

  // ----- Internal holder-list helpers ----- //

  function _addHolder(address addr) internal {
    if (holderIndex[addr] == 0) {
      holders.push(addr);
      holderIndex[addr] = holders.length;
    }
  }

  function _removeHolder(address addr) internal {
    uint256 idx = holderIndex[addr];
    if (idx != 0) {
      uint256 lastIdx = holders.length;
      address lastAddr = holders[lastIdx - 1];
      holders[idx - 1] = lastAddr;
      holderIndex[lastAddr] = idx;
      holders.pop();
      holderIndex[addr] = 0;
    }
  }

  function _updateHolder(address addr) internal {
    if (balanceOf[addr] > 0) {
      _addHolder(addr);
    } else {
      _removeHolder(addr);
    }
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _updateHolder(msg.sender);
    _updateHolder(to);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _updateHolder(from);
    _updateHolder(to);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Token: no ETH supplied");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _updateHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 bal = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(bal);
    _updateHolder(msg.sender);
    dest.transfer(bal);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > holders.length) {
      return address(0);
    }
    return holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Token: no ETH supplied");
    // Cache storage reads into memory once to avoid repeated SLOADs in the loop.
    address[] memory _holders = holders;
    uint256 len = _holders.length;
    uint256 value = msg.value;
    uint256 supply = totalSupply;
    // Note: Solidity 0.7.0 does not perform overflow checks on arithmetic,
    // so `++i` here is already gas-cheap (no `unchecked` block needed).
    for (uint256 i = 0; i < len; ++i) {
      address holder = _holders[i];
      uint256 share = value.mul(balanceOf[holder]).div(supply);
      accruedDividend[holder] = accruedDividend[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return accruedDividend[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amt = accruedDividend[msg.sender];
    accruedDividend[msg.sender] = 0;
    dest.transfer(amt);
  }
}
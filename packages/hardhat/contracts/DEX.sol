// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract
    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address readContract, string _message, uint256 _eth, uint256 _tokens);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address readContract, string _message, uint256 _eth, uint256 _tokens);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(address readContract, uint256 liquidityMinted, uint256 _eth, uint256 _tokens);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(address readContract, uint256 LIquidityBurned, uint256 _eth, uint256 _tokens);


    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function init(uint256 tokens) public payable returns (uint256) {
      require(totalLiquidity == 0, "Dex: init - already has liquidity");
      totalLiquidity = address(this).balance;
      liquidity[msg.sender] = totalLiquidity;
      require(token.transferFrom(msg.sender, address(this), tokens), "DEX: init transfer did not transact");
      return totalLiquidity;
    }

    function price(
      uint256 xInput,
      uint256 xReserves,
      uint256 yReserves
    ) public view returns (uint256 yOutput) {
      uint256 xInputWithFee = xInput.mul(997);
      uint256 numerator = xInputWithFee.mul(yReserves);
      uint256 denominator = (xReserves.mul(1000)).add(xInputWithFee);
      return (numerator / denominator);
    }

    function ethToToken() public payable returns (uint256 tokenOutput) {
      require(msg.value > 0, "Cannot swap 0 ETH");
      uint256 ethReserve = address(this).balance.sub(msg.value); //Calculate balance 'before' adding msg.value
      uint256 tokenReserve = token.balanceOf(address(this));
      tokenOutput = price(msg.value, ethReserve, tokenReserve);
      
      require(token.transfer(msg.sender, tokenOutput), "ethToToken(): reverted swap");
      emit EthToTokenSwap(msg.sender, "Eth to Baloons", msg.value, tokenOutput);
      return tokenOutput;
    }

    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
      require(tokenInput > 0, "Cannot swap 0 tokens");
      uint256 tokenReserve = token.balanceOf(address(this));
      ethOutput = price(tokenInput, tokenReserve, address(this).balance);
      require(token.transferFrom(msg.sender, address(this), tokenInput), "tokenToEth(): reverted swap");
      (bool sent, ) = address(msg.sender).call{value: ethOutput}("");
      require(sent, "tokenToEth(): revert in transferring Eth to you!");
      emit TokenToEthSwap(msg.sender, "Baloons to Eth", ethOutput, tokenInput);
      return ethOutput;
    }

    function deposit() public payable returns (uint256 tokenDeposit) {
      require(msg.value > 0, "deposit(): must deposit eth");
      uint256 tokenReserve = token.balanceOf(address(this));
      uint256 ethReserve = address(this).balance.sub(msg.value); //balance excluding current transaction
      tokenDeposit = msg.value.mul(tokenReserve) / ethReserve;
      token.transferFrom(msg.sender, address(this), tokenDeposit);

      //Keep track of liquidity
      uint256 liquidityMinted = msg.value.mul(totalLiquidity) / ethReserve;
      liquidity[msg.sender] = liquidity[msg.sender].add(liquidityMinted);
      totalLiquidity = totalLiquidity.add(liquidityMinted);

      emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokenDeposit);
      return tokenDeposit;
    }

    function withdraw(uint256 liquidityWithdrawal) public returns (uint256 tokenWithdrawal) {
      require(liquidityWithdrawal > 0, "withdraw(): must withdraw liquidity");
      require(liquidityWithdrawal <= liquidity[address(msg.sender)], "withdraw(): not enough liquidity");
      
      uint256 tokenReserve = token.balanceOf(address(this));
      uint256 ethReserve = address(this).balance;
      uint256 ethWithdrawal = liquidityWithdrawal.mul(ethReserve) / totalLiquidity;
      tokenWithdrawal = liquidityWithdrawal.mul(tokenReserve) / totalLiquidity;
      
      (bool sent, ) = address(msg.sender).call{value: ethWithdrawal}("");
      require(sent, "withdraw(): revert in transferring Eth to you!");
      require(token.transfer(msg.sender, tokenWithdrawal));

      //Keep track of liquidity
      liquidity[address(msg.sender)] = liquidity[address(msg.sender)].sub(liquidityWithdrawal);
      totalLiquidity = totalLiquidity.sub(liquidityWithdrawal);
      
      emit LiquidityRemoved(msg.sender, liquidityWithdrawal, ethWithdrawal, tokenWithdrawal);
      return tokenWithdrawal;
    }
}
pragma solidity ^0.8.0;
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface ICERC20 {
    // ICERC20
    function mint(uint) external returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function supplyRatePerBlock() external returns (uint);
    function redeem(uint) external returns (uint);
    function redeemUnderlying(uint) external returns (uint);
    function borrow(uint) external returns (uint);

    // ctoken
    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function accrueInterest() external returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);
}

interface ICETH {
    // cETH
    function mint() external payable;
    function exchangeRateCurrent() external returns (uint);
    function supplyRatePerBlock() external returns (uint);
    function redeem(uint) external returns (uint);
    function redeemUnderlying(uint) external returns (uint);
    function borrow(uint) external returns (uint);

    // ctoken
    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function accrueInterest() external returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);
}

interface Comptroller {
    function markets(address) external returns (bool, uint);
    function enterMarkets(address[] calldata) external returns (uint[] memory);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
}

contract SmartVault {
  event MyLog(string, uint);

  address public manager;
  address public UNISWAP_ROUTER_ADDRESS=0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public COMPTROLLER_ADDRESS=0x5eAe89DC1C671724A672ff0630122ee834098657;

  address public DAI_ADDRESS=0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa;
  address public MKR_ADDRESS=0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD;
  address public CDAI_ADDRESS=0xF0d0EB522cfa50B716B3b1604C4F0fA6f04376AD;
  address public CETH_ADDRESS=0x41B5844f4680a8C38fBb695b7F9CFd1F64474a72;

  IUniswapV2Router02 public uniswapRouter;
  Comptroller public comptroller;
  mapping(string => address) public tokenAddresses;
  mapping(string => IERC20) public tokenMap;
  mapping(string => ICERC20) public cTokenMap;

  ICETH public cETH;


  constructor() {
    // initialize Uniswap Router to default address
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    comptroller = Comptroller(COMPTROLLER_ADDRESS);

    cETH = ICETH(CETH_ADDRESS);

    // define contract manager
    manager = msg.sender;
    addToken("DAI", DAI_ADDRESS);
    addToken("MKR", MKR_ADDRESS);
    addCToken("CDAI", CDAI_ADDRESS);
    addCToken("CETH", CETH_ADDRESS);
  }

  function deposit() external payable {}

  fallback() external payable {}

  modifier restricted() {
      require(msg.sender == manager, "SMARTVAULT_MANAGER_ERROR");
      _;
  }

  function approveToken(
    address transferAddress,
    uint transferAmount,
    address tokenAddress,
    bool transferFunds
  ) private restricted {
    IERC20 token = IERC20(tokenAddress);
    require(token.approve(transferAddress, transferAmount), "SMARTVAULT_APPROVE_ERROR");
    if (transferFunds){
      require(token.transfer(transferAddress, transferAmount), "SMARTVAULT_IERC20TRANSFER_ERROR");
    }
  }

  function addToken(
    string memory token,
    address tokenAddress
  ) private restricted {
    approveToken(UNISWAP_ROUTER_ADDRESS, 10**24, tokenAddress, false);
    //TODO : what to do here to treat all compound addresses?
    approveToken(CDAI_ADDRESS, 10**24, tokenAddress, false);
    approveToken(CETH_ADDRESS, 10**24, tokenAddress, false);
    tokenAddresses[token] = tokenAddress;
    tokenMap[token] = IERC20(tokenAddress);
  }

  function addCToken(
    string memory token,
    address tokenAddress
  ) private restricted {
    tokenAddresses[token] = tokenAddress;
    cTokenMap[token] = ICERC20(tokenAddress);
  }

  function uniswapTradePath(
    address fromToken,
    address toToken
  ) private pure returns (address[] memory)  {
    // uniswap router takes trade path [tokenA, tokenB, ... tokenZ] - for now we assume are only support token path [tokenA, tokenB]
    address[] memory path = new address[](2);
    path[0] = fromToken;
    path[1] = toToken;
    return path;
  }

  function swapETHforToken(
    string memory exchange,
    uint tradeAmount,
    uint minSwapAmount,
    string memory toToken,
    uint deadline
  ) external payable restricted {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      minSwapAmount=1;
      deadline=block.timestamp+15000;
      uint[] memory amounts=uniswapRouter.swapExactETHForTokens{value : tradeAmount}(minSwapAmount, uniswapTradePath(uniswapRouter.WETH(), tokenAddresses[toToken]), address(this), deadline);
    }
  }

  function swapTokenForToken(
    string memory exchange,
    uint tradeAmount,
    uint minSwapAmount,
    string memory fromToken,
    string memory toToken,
    uint deadline
  ) external restricted {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      minSwapAmount=1;
      deadline=block.timestamp+15000;
      uint[] memory amounts=uniswapRouter.swapExactTokensForTokens(tradeAmount, minSwapAmount, uniswapTradePath(tokenAddresses[fromToken], tokenAddresses[toToken]), address(this), deadline);
    }
  }

  function swapTokenforETH(
    string memory exchange,
    uint tradeAmount,
    uint minSwapAmount,
    string memory fromToken,
    uint deadline
  ) external restricted {
    // TODO : Support more exchanges
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      minSwapAmount=1;
      deadline=block.timestamp+15000;
      uint[] memory amounts=uniswapRouter.swapExactTokensForETH(tradeAmount, minSwapAmount, uniswapTradePath(tokenAddresses[fromToken], uniswapRouter.WETH()), address(this), deadline);
    }
  }

  function addLiquidityTokens(
    string memory exchange,
    string memory tokenA,
    string memory tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      deadline = block.timestamp + 15000;
      (uint amountA, uint amountB, uint liquidity) = uniswapRouter.addLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], amountADesired, amountBDesired, amountAMin, amountBMin, address(this), deadline);
    }
  }

  function addLiquidityETH(
    string memory exchange,
    string memory tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external payable restricted {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      deadline = block.timestamp + 15000;
      (uint amountA, uint amountB, uint liquidity) = uniswapRouter.addLiquidityETH{value : amountADesired}(tokenAddresses[tokenB], amountBDesired, amountBMin, amountAMin, address(this), deadline);
    }
  }

  function removeLiquidityTokens(
    string memory exchange,
    string memory tokenA,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      deadline=block.timestamp+15000;
      (uint amountA, uint amountB) = uniswapRouter.removeLiquidity(tokenAddresses[tokenA], tokenAddresses[tokenB], liquidity, amountAMin, amountBMin, address(this), deadline);
    }
  }

  function removeLiquidityETH(
    string memory exchange,
    string memory tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    uint deadline
  ) external restricted {
    if (keccak256(abi.encodePacked(exchange)) == keccak256(abi.encodePacked("uniswap"))) {
      deadline = block.timestamp + 15000;
      (uint amountA, uint amountB) = uniswapRouter.removeLiquidityETH(tokenAddresses[tokenB], liquidity, amountBMin, amountAMin, address(this), deadline);
    }
  }

  function lendTokens(
      string memory cTokenName,
      uint numTokensToSupply
  ) external restricted {
      // Create a reference to the corresponding cToken contract, like cDAI
      ICERC20 cToken = cTokenMap[cTokenName];//ICERC20(cTokenAddress);
      uint prevBalance = cToken.balanceOf(address(this));
      // Mint cTokens
      uint mintResult = cToken.mint(numTokensToSupply);
      uint currBalance = cToken.balanceOf(address(this));
  }

  function lendETH(
      uint amount,
      address payable cETHContract
  ) external payable restricted {
      // Create a reference to the corresponding cToken contract
      uint prevBalance = cETH.balanceOf(address(this));
      // Mint cTokens
      cETH.mint{value : amount}(); // TODO: unfort we don't get the trade data, it's broadcast to bchain via events
      uint currBalance = cETH.balanceOf(address(this));
  }

  function borrowTokens(
      string memory cTokenName,
      uint toBorrow
  ) public payable {
      ICERC20 cToken = cTokenMap[cTokenName];//ICERC20(cTokenAddress);
      // Supply ETH as collateral, get cETH in return
      cETH.mint{value : msg.value}();
      // Enter the ETH market so you can borrow another type of asset
      address[] memory cTokens = new address[](1);
      cTokens[0] = CETH_ADDRESS;
      uint[] memory errors = comptroller.enterMarkets(cTokens);
      require(errors[0] == 0, "Comptroller.enterMarkets failed.");
      // Get my account's total liquidity value in Compound
      (uint error2, uint liquidity, uint shortfall) = comptroller
          .getAccountLiquidity(address(this));
      require(error2 == 0, "Comptroller.getAccountLiquidity failed");
      require(shortfall == 0, "account underwater");
      require(liquidity > 0, "account has excess collateral");
      // Borrow, check the underlying balance for this contract's address
      cToken.borrow(toBorrow);
      // Get the borrow balance
      uint borrows = cToken.borrowBalanceCurrent(address(this));
  }

  function borrowETH(
      string memory tokenName,
      string memory cTokenName,
      uint toSupply,
      uint toBorrow
  ) public {
      ICERC20 cToken = cTokenMap[cTokenName];//ICERC20(cTokenAddress);
      // Supply underlying as collateral, get cToken in return
      uint error = cToken.mint(toSupply);
      require(error == 0, "ICERC20.mint Error");
      // Enter the market so you can borrow another type of asset
      address[] memory cTokens = new address[](1);
      cTokens[0] = tokenAddresses[cTokenName];
      uint[] memory errors = comptroller.enterMarkets(cTokens);
      require(errors[0] == 0, "Comptroller.enterMarkets failed");
      // Get my account's total liquidity value in Compound
      (uint error2, uint liquidity, uint shortfall) = comptroller
          .getAccountLiquidity(address(this));
      require(error2 == 0, "Comptroller.getAccountLiquidity failed");
      require(shortfall == 0 && liquidity > 0, "account underwater");
      // Borrow, then check the underlying balance for this contract's address
      cETH.borrow(toBorrow);
      uint borrows = cETH.borrowBalanceCurrent(address(this));
  }

  function redeemCTokens(
      uint amount,
      string memory tokenName,
      string memory cTokenName,
      bool redeemType
  ) public {
      // Create a reference to the corresponding cToken contract, like cDAI
      ICERC20 cToken = cTokenMap[cTokenName];//ICERC20(cTokenAddress);
      IERC20 token = tokenMap[tokenName];//IERC20(tokenContract);
      uint prevBalance = token.balanceOf(address(this));
      // `amount` is scaled up, see decimal table here:
      // https://compound.finance/docs#protocol-math
      if (redeemType == true) {
          // Retrieve your asset based on a cToken amount
          cToken.redeem(amount);
      } else {
          // Retrieve your asset based on an amount of the asset
          cToken.redeemUnderlying(amount);
      }
  }

  function redeemCETH(
      uint amount,
      bool redeemType
  ) public {
      if (redeemType == true) {
          // Retrieve your asset based on a cToken amount
          cETH.redeem(amount);
      } else {
          // Retrieve your asset based on an amount of the asset
          cETH.redeemUnderlying(amount);
      }
  }
}

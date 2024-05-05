//SDPX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/tokens/Tuto.sol";
import "src/BalanceOracle.sol";
import "src/RewardRouter.sol";
import "src/RewardTracker.sol";
import "src/StableRewardTracker.sol";





contract TutoScript is Script { 

    function setUp() public {}

    function run() public {

    uint privateKey = vm.envUint("PRIVATE_KEY");
    address account = vm.addr(privateKey);
    // address tutoAddr = 0xB80E94cf1791E0a9cb8B394524A4ebF427076f76;
    address usdcAddr = 0x8c7A265C1C40F65A6F924207fa859da29b581c2B;
    address uniswapV2Pair = 0x8c7A265C1C40F65A6F924207fa859da29b581c2B;
    // address rrAddr = 0x24c17C37F706988c9C6D32aE12Aa2FDf6bc82b92;

    // address fUsdcAddr = 0x33E33173283E1AB3e6E70a6dfcc0995F65d14a66;
    
   


    vm.startBroadcast(privateKey);    

    Tuto tuto = new Tuto(account, 1000000e18);
    address tutoAddr = address(tuto);
    console.log("Tuto Address", tutoAddr);

    RewardRouter rewardRouter = new RewardRouter(tutoAddr, usdcAddr, account);
    address rrAddr = address(rewardRouter);
    console.log("RR Address", rrAddr);

    StableRewardTracker stableRewardTracker = new StableRewardTracker(account, "Fee USDC Tracker", "fUSDC", rrAddr);
    address fUsdcAddr = address(stableRewardTracker);
    console.log("Fee USDC Tracker Address", fUsdcAddr);

    RewardTracker rewardTracker = new RewardTracker(account, "Fee Tuto Tracker", "fTUTO", rrAddr);
    address fTutoAddr = address(rewardTracker);
    console.log("Fee Tuto Tracker Address", fTutoAddr);
    bool test = rewardTracker.stableRewardSystem();
    console.log(test);

    BalanceOracle balanceOracle = new BalanceOracle(account, fUsdcAddr, rrAddr);
    address oracleAddr = address(balanceOracle);
    console.log("Balance Oracle Address", oracleAddr);

    // Initialisze

    rewardRouter.initialize(fUsdcAddr, fTutoAddr, oracleAddr);
    stableRewardTracker.initialize(usdcAddr, oracleAddr);
    rewardTracker.initialize(tutoAddr, usdcAddr);

   
    // StableRewardTracker stableRewardTracker = StableRewardTracker(fUsdcAddr);
    // console.log(stableRewardTracker.isHandler(rrAddr));

    // RewardRouter rewardRouter = RewardRouter(rrAddr);
    // rewardRouter.depositUsdc(10e6);

    // Tuto tuto = Tuto(tutoAddr);
    // string memory name1 = tuto.name();
    // console.log(name1);
    // tuto.setRule(true, uniswapV2Pair, 2000e18, 6000e18);

    vm.stopBroadcast();
    }

}
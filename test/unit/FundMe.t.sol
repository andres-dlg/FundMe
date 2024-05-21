// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "script/DeployFundMe.s.sol";

// Use console to debug the code like console.log(smth)

// Run forge test -vv to test this
// To run a single test use forge test --mt <test function name>

// NOTES ABOUT GAS: 
// - Anvil will simulate that gas cost is ZERO for every tx as default
// - To simulate another gas value we can use vm.gasPrice(<unit256 value>)
// - When you send a Tx, usually you send more gas than the expected gas to be consumed. That's the Gas Limit and Gas used
//   that can be seen in a Tx in Etherscan
// - To see how much you have left in solidity after a Tx has been processed you can use gasLeft() which is a build in solidity 
//   function (https://docs.soliditylang.org/en/v0.8.25/cheatsheet.html#index-5)
// - To calculate the how much a Tx costs you can get the gasLeft() (lets call it gasStart) before the Tx starts, then get 
//    the gasLeft() (lets call it gasEnd) after the Tx has been processed. 
//    Then calculate the gasUsed = (gasStart - gasEnd) * tx.gasprice (a built-in constant)

contract FundMeTest is Test {
    FundMe fundMe;

    // https://book.getfoundry.sh/reference/forge-std/make-addr
    // https://book.getfoundry.sh/cheatcodes/deal
    address USER = makeAddr("fakeUser");

    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    // This function runs every time a test is run
    function setUp() public {
        fundMe = new DeployFundMe().run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMimimumUSD() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        // As the msg.sender is this contract (because here is where the contract is deployed - in the setUp function-), instead of
        // msg.sender I can use address(this) in the test -> This is if I create the fundMe instance in the setUp function

        // UPDATE: Now that I'm creating the instance in the DeployFundMe script, I can use msg.sender instead of address(this)

        assertEq(fundMe.getOwner(), msg.sender);
    }

    // What can do to work with addresses outside our system
    // 1. Unit
    //    - Testing a specific part of our code
    // 2. Integration
    //    - Testing how our code works with other parts of the code
    // 3. Forked
    //    - Testing our code on a simulated real environment
    // 4. Staging
    //    - Testing our code in a real environment that is not prod

    // In this case we are going to make a Forked test since getVersion needs to know the contract address of something that
    // doesn't exist in our simulated environment (Foundry), but it exists in Sepolia blockchain.
    // So we need to set the rpc-url in the test
    // The command should be:
    // forge test -vv --fork-url=$SEPOLIA_RPC_URL

    // IMPORTANT: Avoid using too much --fork-url since it will consume the usage in Alchemy. Instead you can use mocks until you
    // need to use a real network

    // To test how much coverage we have in our code, we can use forge coverage
    // forge coverage --fork-url=$SEPOLIA_RPC_URL

    function testPriceFeedVersionIsAccurate() public view {
        assertEq(fundMe.getVersion(), 4);
    }

    // https://book.getfoundry.sh/cheatcodes/expect-revert
    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // Hey, the next line, should revert! If the next line doesn't reverts the Tx, the test fails
        fundMe.fund(); // 0 is default value
    }

    function testFundUpdatesFundedDataStructure() public funded {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddFunderToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    // To have benchmark of how much gas is spent there is a command -> forge snapshot --mt <testname>
    // This command will create a file called .gas-snapshot in the root project directory 
    // with the following content -> FundMeTest:testWithdrawWithASingleFounder() (gas: 87245)
    function testWithdrawWithASingleFounder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFounders() public funded {
        // Arrange

        // It's uint160 because we are going to cast it to an address and a uint160 has the same number of bytes as an address
        uint160 numberOfFounders = 10; 
        uint160 startingFunderIndex = 1; // We don't start from 0 because as we are going to cast it to an address, the address(0) sometimes reverts Txs
        for (uint160 i = startingFunderIndex; i < numberOfFounders; i++) {
            // Impersonate next Tx as new address -> vm.prank
            // Add funds to new address -> vm.deal
            // OR we can use prank and deal combined -> vm.hoax
            hoax(address(i), SEND_VALUE);
            // Fund contract -> fundMe.fund()
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        // Just like vm.sendBroadcast() and vm.stopBroadcast() we can use the following syntax for prank. It's an alternative to prior tests
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawWithASingleFounderCheaper() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdrawCheaper();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFoundersCheaper() public funded {
        // Arrange
        uint160 numberOfFounders = 10; 
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFounders; i++) {
            hoax(address(i), SEND_VALUE);
            // Fund contract -> fundMe.fund()
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdrawCheaper();
        vm.stopPrank();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    // https://book.getfoundry.sh/cheatcodes/prank
    modifier funded() {
        vm.prank(USER); // The next Tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();
        _;
    }
}

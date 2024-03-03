// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract AllowanceContract is Ownable {
    using SafeMath for uint256;

    struct Allowance {
        uint256 allowanceAmount;
        uint256 allowancePeriodInDays;
        uint256 lastAllowanceTimestamp;
        uint256 unspentAllowance;
    }

    constructor () Ownable(msg.sender) {}

    mapping(address => Allowance) public allowances;

    event MoneyReceived(address indexed sender, uint256 amount);
    event MoneySent(address indexed receiver, uint256 amount);
    event AllowanceCreated(address indexed recipient, Allowance allowance);
    event AllowanceDeleted(address indexed recipient);
    event AllowanceChanged(address indexed recipient, Allowance allowance);

    receive() external payable {
        emit MoneyReceived(msg.sender, msg.value);
    }

    // function addMoneyToContract(uint256 amount, address sender) public payable {
    //     require(msg.value == amount, "Incorrect amount sent");
    //     require(sender == msg.sender, "Incorrect sender specified");
    //     emit MoneyReceived(sender, msg.value);
    // }



    function withdrawFromWalletBalance(address payable addr, uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Wallet balance too low to fund withdraw");
        addr.transfer(amount);
        emit MoneySent(addr, amount);
    }

    function withdrawAllFromWalletBalance(address payable addr) public onlyOwner {
        withdrawFromWalletBalance(addr, address(this).balance);
    }

    function addAllowance(address recipient, uint256 allowanceAmount, uint256 allowancePeriodInDays) public onlyOwner {
        require(allowances[recipient].allowanceAmount == 0, "Allowance already exists");
        require(address(this).balance >= allowanceAmount, "Wallet balance too low to add allowance");

        Allowance memory allowance;
        allowance.allowanceAmount = allowanceAmount;
        allowance.allowancePeriodInDays = allowancePeriodInDays;
        allowance.lastAllowanceTimestamp = block.timestamp;
        allowance.unspentAllowance = allowanceAmount;

        allowances[recipient] = allowance;
        emit AllowanceCreated(recipient, allowance);
    }

    function removeAllowance(address payable recipient) public onlyOwner {
        require(allowances[recipient].allowanceAmount > 0, "Allowance does not exist");

        if (allowances[recipient].unspentAllowance > 0) {
            recipient.transfer(allowances[recipient].unspentAllowance);
        }

        delete allowances[recipient];
        emit AllowanceDeleted(recipient);
    }

    function getPaidAllowance(uint256 amount) public {
        Allowance storage allowance = allowances[msg.sender];
        require(allowance.allowanceAmount > 0, "You're not a recipient of an allowance");
        require(block.timestamp >= allowance.lastAllowanceTimestamp.add(allowance.allowancePeriodInDays), "Allowance period has not elapsed yet");
        require(address(this).balance >= amount, "Wallet balance too low to pay allowance");

        uint256 numAllowances = (block.timestamp.sub(allowance.lastAllowanceTimestamp)).div(allowance.allowancePeriodInDays);
        allowance.unspentAllowance = allowance.allowanceAmount.mul(numAllowances).add(allowance.unspentAllowance);
        allowance.lastAllowanceTimestamp = numAllowances.mul(allowance.allowancePeriodInDays).add(allowance.lastAllowanceTimestamp);

        require(allowance.unspentAllowance >= amount, "You asked for more allowance than you're owed");
        payable(msg.sender).transfer(amount);
        allowance.unspentAllowance = allowance.unspentAllowance.sub(amount);

        emit MoneySent(msg.sender, amount);
        emit AllowanceChanged(msg.sender, allowance);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


}

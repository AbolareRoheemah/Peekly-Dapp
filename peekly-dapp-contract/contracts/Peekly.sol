// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Peekly is Ownable {
    uint256 public platformFeePercent = 5; // 5% fee, adjustable by owner
    address public feeRecipient; // Where platform fees go (your wallet)

    // Mapping to track if a user has paid for a specific contentID
    mapping(address => mapping(string => bool)) public hasPaid;

    // 0x0 for ETH, else ERC-20 address
    event Paid(
        address indexed payer,
        address indexed creator,
        string contentID,
        uint256 amount,
        address token
    );

    event PlatformFeeChanged(uint256 oldFee, uint256 newFee);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event WithdrawnETH(address indexed to, uint256 amount);
    event WithdrawnToken(address indexed token, address indexed to, uint256 amount);

    constructor(address _feeRecipient) Ownable(msg.sender) {
        require(_feeRecipient != address(0), "Fee recipient cannot be zero address");
        feeRecipient = _feeRecipient;
    }

    // Pay in native ETH
    function payETH(address creator, string calldata contentID) external payable {
        require(msg.value > 0, "Payment must be greater than 0");
        require(creator != address(0), "Creator cannot be zero address");
        require(!hasPaid[msg.sender][contentID], "Already paid for this content");

        uint256 fee = (msg.value * platformFeePercent) / 100;
        uint256 creatorAmount = msg.value - fee;

        (bool feeSent, ) = payable(feeRecipient).call{value: fee}("");
        require(feeSent, "Fee transfer failed");

        (bool creatorSent, ) = payable(creator).call{value: creatorAmount}("");
        require(creatorSent, "Creator transfer failed");

        hasPaid[msg.sender][contentID] = true;

        emit Paid(msg.sender, creator, contentID, msg.value, address(0));
    }

    // Pay in ERC-20 token (e.g., LSK)
    // Popular token addresses (Ethereum mainnet):
    // USDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    // USDT: 0xdAC17F958D2ee523a2206206994597C13D831ec7
    // DAI:  0x6B175474E89094C44Da98b954EedeAC495271d0F
    // WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    // LINK: 0x514910771AF9Ca656af840dff83E8264EcF986CA
    function payToken(address creator, string calldata contentID, uint256 amount, address tokenAddress) external {
        require(amount > 0, "Payment must be greater than 0");
        require(creator != address(0), "Creator cannot be zero address");
        require(tokenAddress != address(0), "Token address cannot be zero address");
        require(!hasPaid[msg.sender][contentID], "Already paid for this content");

        IERC20 token = IERC20(tokenAddress);

        uint256 fee = (amount * platformFeePercent) / 100;
        uint256 creatorAmount = amount - fee;

        // Check allowance
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Insufficient token allowance");

        // Transfer fee to feeRecipient
        bool feeSent = token.transferFrom(msg.sender, feeRecipient, fee);
        require(feeSent, "Fee transfer failed");

        // Transfer remaining amount to creator
        bool creatorSent = token.transferFrom(msg.sender, creator, creatorAmount);
        require(creatorSent, "Creator transfer failed");

        hasPaid[msg.sender][contentID] = true;

        emit Paid(msg.sender, creator, contentID, amount, tokenAddress);
    }

    // Owner functions
    function setPlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Fee too high"); // Cap at 10%
        uint256 oldFee = platformFeePercent;
        platformFeePercent = newFee;
        emit PlatformFeeChanged(oldFee, newFee);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Fee recipient cannot be zero address");
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientChanged(oldRecipient, newRecipient);
    }

    // Withdraw stuck ETH
    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "Recipient cannot be zero address");
        require(address(this).balance >= amount, "Insufficient ETH balance");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "ETH withdrawal failed");
        emit WithdrawnETH(to, amount);
    }

    // Withdraw stuck ERC20 tokens
    function withdrawToken(address tokenAddress, address to, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "Token address cannot be zero address");
        require(to != address(0), "Recipient cannot be zero address");
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient token balance");
        bool sent = token.transfer(to, amount);
        require(sent, "Token withdrawal failed");
        emit WithdrawnToken(tokenAddress, to, amount);
    }
}
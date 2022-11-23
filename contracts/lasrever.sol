// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract LASREVER is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;

    mapping(address => bool) private _isBlacklisted;
    bool private _swapping;
    uint256 private _launchTime;
    uint256 private _launchBlock;

    address private feeWallet;

    uint256 public maxTransactionAmount;
    uint256 public swapTokensAtAmount;
    uint256 public maxWallet;

    bool public limitsInEffect = true;
    bool public tradingActive = false;
    bool public _reduceFee = false;
    uint256 private _reduceTime;
    uint256 deadBlocks = 0;

    mapping(address => uint256) private _holderLastTransferTimestamp;
    bool public transferDelayEnabled = false;

    uint256 private _marketingFee;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedMaxTransactionAmount;

    mapping(address => uint256) private _holderFirstBuyTimestamp;

    mapping(address => bool) private automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event feeWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    constructor() ERC20("LASREVER", "$LSVR") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        excludeFromMaxTransaction(address(_uniswapV2Router), true);
        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), DAI);
        excludeFromMaxTransaction(address(uniswapV2Pair), true);
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 totalSupply = 987_654_321 * 1e18;

        maxTransactionAmount = (totalSupply * 1) / 100;
        maxWallet = (totalSupply * 1) / 100;
        swapTokensAtAmount = (totalSupply * 15) / 10000;

        _marketingFee = 4;

        feeWallet = address(owner());
        // set as fee wallet

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        _approve(owner(), address(_uniswapV2Router), type(uint256).max);

        ERC20(DAI).approve(address(_uniswapV2Router), type(uint256).max);
        ERC20(DAI).approve(address(this), type(uint256).max);

        _mint(owner(), totalSupply);
    }

    function readySteadyGo() external onlyOwner {
        deadBlocks = 0;
        tradingActive = true;
        _launchTime = block.timestamp;
        _launchBlock = block.number;
    }

    // remove limits after token is stable
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        return true;
    }

    // disable Transfer delay - cannot be reenabled
    function disableTransferDelay() external onlyOwner returns (bool) {
        transferDelayEnabled = false;
        return true;
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner returns (bool){
        require(newAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% total supply.");
        require(newAmount <= (totalSupply() * 5) / 1000, "Swap amount cannot be higher than 0.5% total supply.");
        swapTokensAtAmount = newAmount;
        return true;
    }

    function updateMaxTxnAmount(uint256 newNum) external onlyOwner {
        require(newNum >= ((totalSupply() * 1) / 1000) / 1e18, "Cannot set maxTransactionAmount lower than 0.1%");
        maxTransactionAmount = newNum * 1e18;
    }

    function updateMaxWalletAmount(uint256 newNum) external onlyOwner {
        require(newNum >= ((totalSupply() * 5) / 1000) / 1e18, "Cannot set maxWallet lower than 0.5%");
        maxWallet = newNum * 1e18;
    }

    function excludeFromMaxTransaction(address updAds, bool isEx) public onlyOwner {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    function updateFees(uint256 marketingFee) external onlyOwner {
        _marketingFee = marketingFee;
        _reduceFee = false;
        require(_marketingFee <= 10, "Must keep fees at 10% or less");
    }

    function updateReduceFee(bool reduceFee) external onlyOwner {
        _reduceFee = reduceFee;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateFeeWallet(address newWallet) external onlyOwner {
        emit feeWalletUpdated(newWallet, feeWallet);
        feeWallet = newWallet;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function getFee() public view returns (uint256) {
        return _getReducedFee(_marketingFee, 1);
    }

    function setBlacklisted(address[] memory blacklisted_) public onlyOwner {
        for (uint256 i = 0; i < blacklisted_.length; i++) {
            if (blacklisted_[i] != uniswapV2Pair && blacklisted_[i] != address(uniswapV2Router)) {
                _isBlacklisted[blacklisted_[i]] = false;
            }
        }
    }

    function delBlacklisted(address[] memory blacklisted_) public onlyOwner {
        for (uint256 i = 0; i < blacklisted_.length; i++) {
            _isBlacklisted[blacklisted_[i]] = false;
        }
    }

    function isSniper(address addr) public view returns (bool) {
        return _isBlacklisted[addr];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(!_isBlacklisted[from], "Your address has been marked as a sniper, you are unable to transfer or swap.");
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }
        if (tradingActive) {
            require(block.number >= _launchBlock + deadBlocks, "NOT BOT");
        }
        if (limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !_swapping
            ) {
                if (!tradingActive) {
                    require(_isExcludedFromFees[from] || _isExcludedFromFees[to], "Trading is not active.");
                }

                if (balanceOf(to) == 0 && _holderFirstBuyTimestamp[to] == 0) {
                    _holderFirstBuyTimestamp[to] = block.timestamp;
                }

                if (transferDelayEnabled) {
                    if (to != owner() && to != address(uniswapV2Router) && to != address(uniswapV2Pair)) {
                        require(
                            _holderLastTransferTimestamp[tx.origin] < block.number,
                            "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed."
                        );
                        _holderLastTransferTimestamp[tx.origin] = block.number;
                    }
                }

                // when buy
                if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                    require(amount <= maxTransactionAmount, "Buy transfer amount exceeds the maxTransactionAmount.");
                    require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
                }
                // when sell
                else if (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
                    require(amount <= maxTransactionAmount, "Sell transfer amount exceeds the maxTransactionAmount.");
                } else if (!_isExcludedMaxTransactionAmount[to]) {
                    require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
                }
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
        if (
            canSwap &&
            !_swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            _swapping = true;
            swapBack();
            _swapping = false;
        }

        bool takeFee = !_swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        if (takeFee) {
            uint256 totalFees =  _getReducedFee(_marketingFee, 1);
            if (totalFees > 0) {
                fees = amount.mul(totalFees).div(100);
                if (fees > 0) {
                    super._transfer(from, address(this), fees);
                }
                amount -= fees;
            }
        }

        super._transfer(from, to, amount);
    }

    function _getReducedFee(uint256 initial, uint256 minFee) private view returns (uint256){
        if (!_reduceFee) {
            return initial;
        }
        uint256 time = block.timestamp - _launchTime;
        uint256 amountToReduce = time / 10 / 60;
        if (amountToReduce >= initial) {
            return minFee;
        }
        uint256 reducedAmount = initial - amountToReduce;
        return reducedAmount > minFee ? reducedAmount : minFee;
    }

    function _swapTokensForDai(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = DAI;

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            owner(),
            block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance == 0) return;
        if (contractBalance > swapTokensAtAmount) {
            contractBalance = swapTokensAtAmount;
        }
        uint256 amountToSwapForDAI = contractBalance;
        _swapTokensForDai(contractBalance);
    }

    function importantMessageFromTeam(string memory input) external onlyOwner {}

    function forceSwap() external onlyOwner {
        _swapTokensForDai(balanceOf(address(this)));
    }

    function forceSend() external onlyOwner {
        uint256 balance = ERC20(DAI).balanceOf(address(this));
        _approve(address(this), address(uniswapV2Router), balance);
        ERC20(DAI).transfer(msg.sender, balance);
    }

    receive() external payable {}
}

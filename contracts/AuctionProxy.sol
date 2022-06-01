// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IAuctionProxy.sol";
import "./interfaces/ClipperLike.sol";
import "./interfaces/GemJoinLike.sol";
import "./interfaces/UsbGemLike.sol";
import "./interfaces/DogLike.sol";
import "./interfaces/VatLike.sol";
import "./ceros/interfaces/IHelioProvider.sol";
import "./ceros/interfaces/IDao.sol";

uint256 constant RAY = 10**27;

contract AuctionProxy is IAuctionProxy {
  using SafeERC20 for IERC20;
  mapping(address => uint256) public wards;

  function rely(address usr) external auth {
    wards[usr] = 1;
  }

  function deny(address usr) external auth {
    wards[usr] = 0;
  }

  modifier auth() {
    require(wards[msg.sender] == 1, "Interaction/not-authorized");
    _;
  }

  IDao public dao;

  modifier onlyDao() {
    require(msg.sender == address(dao), "Only dao contract can call");
    _;
  }

  constructor() {
    wards[msg.sender] = 1;
  }

  function setDao(address _dao) external auth {
    dao = IDao(_dao);
  }

  function startAuction(
    address user,
    address keeper,
    IERC20 usb,
    UsbGemLike usbJoin,
    VatLike vat,
    DogLike dog,
    IHelioProvider helioProvider,
    CollateralType calldata collateral
  ) external onlyDao returns (uint256 id) {
    uint256 usbBal = usb.balanceOf(address(this));
    id = dog.bark(collateral.ilk, user, address(this));

    usbJoin.exit(address(this), vat.usb(address(this)) / RAY);
    usbBal = usb.balanceOf(address(this)) - usbBal;
    usb.transfer(keeper, usbBal);

    // Burn any derivative token (hBNB incase of ceabnbc collateral)
    if (address(helioProvider) != address(0)) {
      helioProvider.daoBurn(user, ClipperLike(collateral.clip).sales(id).lot);
    }
  }

  function buyFromAuction(
    address user,
    uint256 auctionId,
    uint256 collateralAmount,
    uint256 maxPrice,
    address receiverAddress,
    IERC20 hay,
    UsbGemLike hayJoin,
    VatLike vat,
    IHelioProvider helioProvider,
    CollateralType calldata collateral
  ) external onlyDao {
    // Balances before
    uint256 usbBal = hay.balanceOf(address(this));
    uint256 gemBal = collateral.gem.gem().balanceOf(address(this));

    uint256 usbMaxAmount = (maxPrice * collateralAmount) / RAY;

    hay.transferFrom(user, address(this), usbMaxAmount);
    hayJoin.join(address(this), usbMaxAmount);

    vat.hope(address(collateral.clip));
    address urn = ClipperLike(collateral.clip).sales(auctionId).usr; // Liquidated address

    dao.dropRewards(address(hay), urn);

    uint256 leftover = vat.gem(collateral.ilk, urn); // userGemBalanceBefore
    ClipperLike(collateral.clip).take(auctionId, collateralAmount, maxPrice, address(this), "");
    leftover = vat.gem(collateral.ilk, urn) - leftover; // leftover

    collateral.gem.exit(address(this), vat.gem(collateral.ilk, address(this)));
    hayJoin.exit(address(this), vat.usb(address(this)) / RAY);

    // Balances rest
    usbBal = hay.balanceOf(address(this)) - usbBal;
    gemBal = collateral.gem.gem().balanceOf(address(this)) - gemBal;
    hay.transfer(receiverAddress, usbBal);

    if (address(helioProvider) != address(0)) {
      collateral.gem.gem().safeTransfer(address(helioProvider), gemBal);
      IHelioProvider(helioProvider).liquidation(receiverAddress, gemBal); // Burn router ceToken and mint abnbc to receiver

      if (leftover != 0) {
        // Auction ended with leftover
        vat.flux(collateral.ilk, urn, address(this), leftover);
        collateral.gem.exit(address(helioProvider), leftover); // Router (disc) gets the remaining ceabnbc
        IHelioProvider(helioProvider).liquidation(urn, leftover); // Router burns them and gives abnbc remaining
      }
    } else {
      collateral.gem.gem().safeTransfer(receiverAddress, gemBal);
    }
  }

  function getAllActiveAuctionsForClip(ClipperLike clip)
    external
    view
    returns (Sale[] memory sales)
  {
    uint256[] memory auctionIds = clip.list();
    uint256 auctionsCount = auctionIds.length;
    sales = new Sale[](auctionsCount);
    for (uint256 i = 0; i < auctionsCount; i++) {
      sales[i] = clip.sales(auctionIds[i]);
    }
  }
}
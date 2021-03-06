// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "witnet-solidity-bridge/contracts/interfaces/IWitnetRandomness.sol";

contract LuckyDraw is Ownable {
  uint8 internal drawTimesForThirdPrize;
  uint8 internal drawTimesForFourthPrize;
  uint8 internal requestStatus;
  uint8 internal fetchStatus;

  uint32 internal constant TOTAL_GRAND_PRIZE = 1;
  uint32 internal constant TOTAL_FIRST_PRIZE = 4;
  uint32 internal constant TOTAL_SECOND_PRIZE = 15;
  uint32 internal constant TOTAL_THIRD_PRIZE = 200;
  uint32 internal constant TOTAL_FOURTH_PRIZE = 1000;
  uint32 internal constant TOTAL_PARTICIPATION = 180000;

  bytes32 public randomnessForGrandPrize;
  bytes32 public randomnessForFirstPrize;
  bytes32 public randomnessForSecondPrize;
  bytes32 public randomnessForThirdPrize;
  bytes32 public randomnessForFourthPrize;

  uint256 internal thirdIndex;
  uint256 internal fourthIndex;

  uint256 public blockForLatestRandomizing;
  uint256 public blockForGrandPrize;
  uint256 public blockForFirstPrize;
  uint256 public blockForSecondPrize;
  uint256 public blockForThirdPrize;
  uint256 public blockForFourthPrize;

  IWitnetRandomness public immutable witnet;
  // winner info: 5->grand prize,1->first prize,2->second prize,3->third prize,4->fourth prize,0->No win
  mapping(uint256 => uint256) public winnerInfo;
  uint256[] internal listForGrandPrize;
  uint256[] internal listForFirstPrize;
  uint256[] internal listForSecondPrize;
  uint256[] internal listForThirdPrize;
  uint256[] internal listForFourthPrize;
  uint256[] internal lists;

  event RandomnessRequested(uint256 prizeType, uint256 blockNumber);

  event RandomnessUpdated(uint256 prizeType, uint256 blockNumber, bytes32 randomness);

  event WinnerListUpdate(
    uint256 prizeType,
    uint256 executionTimes,
    uint256 loopIndex,
    uint256 winnersLength,
    uint256[] winners
  );

  /**
   * @notice Constructor
   * @param _witnet: address of witnet randomness generator
   */
  constructor(IWitnetRandomness _witnet) {
    require(address(_witnet) != address(0), "Lottery: the witnet is the zero address");
    witnet = _witnet;
  }

  receive() external payable {}

  /**
   * @notice Request a random number for each prize
   * @dev Only callable by owner
   */
  function requestRandomNumber(uint256 prizeType) external payable onlyOwner {
    require(blockForLatestRandomizing < block.number, "Lottery: the block has been used");
    require(msg.value > 0, "Lottery: the value must be greater than zero");
    if (prizeType == 0) {
      require(
        requestStatus == 1,
        "Lottery: it is not yet the turn of the grand prize operation or the grand prize has been operated"
      );
      requestStatus = 5;
      blockForGrandPrize = block.number;
    } else if (prizeType == 1) {
      require(
        requestStatus == 2,
        "Lottery: it is not yet the turn of the first prize operation or the first prize has been operated"
      );
      requestStatus = 1;
      blockForFirstPrize = block.number;
    } else if (prizeType == 2) {
      require(
        requestStatus == 3,
        "Lottery: it is not yet the turn of the second prize operation or the second prize has been operated"
      );
      requestStatus = 2;
      blockForSecondPrize = block.number;
    } else if (prizeType == 3) {
      require(
        requestStatus == 4,
        "Lottery: it is not yet the turn of the third prize operation or the third prize has been operated"
      );
      requestStatus = 3;
      blockForThirdPrize = block.number;
    } else if (prizeType == 4) {
      require(
        requestStatus == 0,
        "Lottery: it is not yet the turn of the fourth prize operation or the fourth prize has been operated"
      );
      requestStatus = 4;
      blockForFourthPrize = block.number;
    } else {
      revert("Lottery: the prize does not exist");
    }
    blockForLatestRandomizing = block.number;
    uint256 _usedFunds = witnet.randomize{value: msg.value}();
    if (_usedFunds < msg.value) {
      payable(msg.sender).transfer(msg.value - _usedFunds);
    }
    emit RandomnessRequested(prizeType, block.number);
  }

  /**
   * @notice Update the random number for each prize based on the randomResult generated by Witnet's fallback
   * @dev Only callable by owner
   */
  function fetchRandomNumber(uint256 prizeType) external onlyOwner {
    uint256 blockNumber;
    if (prizeType == 1) {
      require(
        fetchStatus == 2,
        "Lottery: it is not yet the turn of the first prize operation or the first prize has been operated"
      );
      fetchStatus = 1;
      blockNumber = blockForFirstPrize;
    } else if (prizeType == 2) {
      require(
        fetchStatus == 3,
        "Lottery: it is not yet the turn of the second prize operation or the second prize has been operated"
      );
      fetchStatus = 2;
      blockNumber = blockForSecondPrize;
    } else if (prizeType == 3) {
      require(
        fetchStatus == 4,
        "Lottery: it is not yet the turn of the third prize operation or the third prize has been operated"
      );
      fetchStatus = 3;
      blockNumber = blockForThirdPrize;
    } else if (prizeType == 4) {
      require(
        fetchStatus == 0,
        "Lottery: it is not yet the turn of the fourth prize operation or the fourth prize has been operated"
      );
      fetchStatus = 4;
      blockNumber = blockForFourthPrize;
    } else if (prizeType == 0) {
      require(
        fetchStatus == 1,
        "Lottery: it is not yet the turn of the grand prize operation or the grand prize has been operated"
      );
      fetchStatus = 5;
      blockNumber = blockForGrandPrize;
    } else {
      revert("Lottery: the prize does not exist");
    }
    require(blockNumber > 0, "Lottery: pending randomize");
    bytes32 randomValue = witnet.getRandomnessAfter(blockNumber);
    if (prizeType == 1) {
      randomnessForFirstPrize = randomValue;
    } else if (prizeType == 2) {
      randomnessForSecondPrize = randomValue;
    } else if (prizeType == 3) {
      randomnessForThirdPrize = randomValue;
    } else if (prizeType == 4) {
      randomnessForFourthPrize = randomValue;
    } else {
      randomnessForGrandPrize = randomValue;
    }
    emit RandomnessUpdated(prizeType, blockNumber, randomValue);
  }

  /**
   * @notice View random number for each prize based on the randomResult generated by Witnet's fallback
   * @param prizeType: prize type
   * @return randomNumber: generated by Witnet's fallback
   */
  function getRandomNumber(uint256 prizeType) external view returns (bytes32) {
    uint256 blockNumber;
    if (prizeType == 1) {
      blockNumber = blockForFirstPrize;
    } else if (prizeType == 2) {
      blockNumber = blockForSecondPrize;
    } else if (prizeType == 3) {
      blockNumber = blockForThirdPrize;
    } else if (prizeType == 4) {
      blockNumber = blockForFourthPrize;
    } else {
      blockNumber = blockForGrandPrize;
    }
    require(blockNumber > 0, "Lottery: pending randomize");
    return witnet.getRandomnessAfter(blockNumber);
  }

  /**
   * @notice View all winner for each prize
   * @param prizeType: prize type
   */
  function getWinnerList(uint256 prizeType) public view returns (uint256[] memory) {
    if (prizeType == 1) {
      return listForFirstPrize;
    } else if (prizeType == 2) {
      return listForSecondPrize;
    } else if (prizeType == 3) {
      return listForThirdPrize;
    } else if (prizeType == 4) {
      return listForFourthPrize;
    } else {
      return listForGrandPrize;
    }
  }

  /**
   * @notice Which prize to draw next
   */
  function drawStatus() public view returns (uint256) {
    if (listForFourthPrize.length != TOTAL_FOURTH_PRIZE) {
      return 4;
    } else if (listForThirdPrize.length != TOTAL_THIRD_PRIZE) {
      return 3;
    } else if (listForSecondPrize.length != TOTAL_SECOND_PRIZE) {
      return 2;
    } else if (listForFirstPrize.length != TOTAL_FIRST_PRIZE) {
      return 1;
    } else if (listForGrandPrize.length != TOTAL_GRAND_PRIZE) {
      return 0;
    } else {
      return 5;
    }
  }

  /**
   * @notice Check if each prize has finished
   * @param prizeType: prize type
   * @return true: finished
   */
  function isFinished(uint256 prizeType) public view returns (bool) {
    if (prizeType == 1) {
      return listForFirstPrize.length == TOTAL_FIRST_PRIZE;
    } else if (prizeType == 2) {
      return listForSecondPrize.length == TOTAL_SECOND_PRIZE;
    } else if (prizeType == 3) {
      return listForThirdPrize.length == TOTAL_THIRD_PRIZE;
    } else if (prizeType == 4) {
      return listForFourthPrize.length == TOTAL_FOURTH_PRIZE;
    } else {
      return listForGrandPrize.length == TOTAL_GRAND_PRIZE;
    }
  }

  /**
   * @notice Start the lottery
   * @dev Only callable by owner
   * @param prizeType: 0->grand prize,1->first prize,2->second prize,3->third prize,4->fourth prize
   */
  function pickWinner(uint256 prizeType) public onlyOwner {
    if (prizeType == 0) {
      require(listForFirstPrize.length == TOTAL_FIRST_PRIZE, "Lottery: the first prize has not been drawn");
      require(listForGrandPrize.length < TOTAL_GRAND_PRIZE, "Lottery: the prize has been drawn out");
      pickWinnerForGrand(prizeType);
    } else if (prizeType == 1) {
      require(listForSecondPrize.length == TOTAL_SECOND_PRIZE, "Lottery: the second prize has not been drawn");
      require(listForFirstPrize.length < TOTAL_FIRST_PRIZE, "Lottery: the prize has been drawn out");
      pickWinnerForFirst(prizeType);
    } else if (prizeType == 2) {
      require(listForThirdPrize.length == TOTAL_THIRD_PRIZE, "Lottery: the third prize has not been drawn");
      require(listForSecondPrize.length < TOTAL_SECOND_PRIZE, "Lottery: the prize has been drawn out");
      pickWinnerForSecond(prizeType);
    } else if (prizeType == 3) {
      require(listForFourthPrize.length == TOTAL_FOURTH_PRIZE, "Lottery: the fourth prize has not been drawn");
      require(listForThirdPrize.length < TOTAL_THIRD_PRIZE, "Lottery: the prize has been drawn out");
      pickWinnerForThird(prizeType);
    } else if (prizeType == 4) {
      require(listForFourthPrize.length < TOTAL_FOURTH_PRIZE, "Lottery: the prize has been drawn out");
      pickWinnerForFourth(prizeType);
    } else {
      revert("Lottery: the prize does not exist");
    }
  }

  /// @dev Returns index of the Most Significant Bit of the given number, applying De Bruijn O(1) algorithm.
  function _msbDeBruijn32(uint32 _v) internal pure returns (uint8) {
    uint8[32] memory _bitPosition = [
      0,
      9,
      1,
      10,
      13,
      21,
      2,
      29,
      11,
      14,
      16,
      18,
      22,
      25,
      3,
      30,
      8,
      12,
      20,
      28,
      15,
      17,
      24,
      7,
      19,
      27,
      23,
      6,
      26,
      5,
      4,
      31
    ];
    _v |= _v >> 1;
    _v |= _v >> 2;
    _v |= _v >> 4;
    _v |= _v >> 8;
    _v |= _v >> 16;
    return _bitPosition[uint32(_v * uint256(0x07c4acdd)) >> 27];
  }

  /**
   * @notice Wrapping into a 256-bit random value
   * @param randomValue: generated by Witnet's fallback
   * @param i: loop index
   */
  function random(bytes32 randomValue, uint256 i) internal view returns (uint256) {
    bytes32 randomSeed = keccak256(abi.encodePacked(randomValue, i, block.number, block.timestamp));
    return uint256(random(TOTAL_PARTICIPATION, i, randomSeed));
  }

  /**
   * @notice Generates a pseudo-random number uniformly distributed within the range [0 .. _range), by using
   * the given `_nonce` value and the given `_seed` as a source of entropy.
   * @param _range Range within which the uniformly-distributed random number will be generated.
   * @param _nonce Nonce value enabling multiple random numbers from the same randomness value.
   * @param _seed Seed value used as entropy source.
   */
  function random(
    uint32 _range,
    uint256 _nonce,
    bytes32 _seed
  ) internal pure virtual returns (uint32) {
    uint8 _flagBits = uint8(255 - _msbDeBruijn32(_range));
    uint256 _number = uint256(keccak256(abi.encode(_seed, _nonce))) & uint256(2**_flagBits - 1);
    return uint32((_number * _range) >> _flagBits);
  }

  function pickWinnerForGrand(uint256 prizeType) internal {
    uint256 loopIndex;
    bytes32 randomValue = randomnessForGrandPrize;
    require(randomValue != "", "Lottery: pending randomize");
    for (uint256 i = 0; i < TOTAL_PARTICIPATION; i++) {
      uint256 randomNumber = 1 + random(randomValue, i);
      if (winnerInfo[randomNumber] == 0) {
        winnerInfo[randomNumber] = 5;
        listForGrandPrize.push(randomNumber);
      }
      if (listForGrandPrize.length == TOTAL_GRAND_PRIZE) {
        loopIndex = i;
        break;
      }
    }
    emit WinnerListUpdate(prizeType, 1, loopIndex, listForGrandPrize.length, listForGrandPrize);
  }

  function pickWinnerForFirst(uint256 prizeType) internal {
    uint256 loopIndex;
    bytes32 randomValue = randomnessForFirstPrize;
    require(randomValue != "", "Lottery: pending randomize");
    for (uint256 i = 0; i < TOTAL_PARTICIPATION; i++) {
      uint256 randomNumber = 1 + random(randomValue, i);
      if (winnerInfo[randomNumber] == 0) {
        winnerInfo[randomNumber] = 1;
        listForFirstPrize.push(randomNumber);
      }
      if (listForFirstPrize.length == TOTAL_FIRST_PRIZE) {
        loopIndex = i;
        break;
      }
    }
    emit WinnerListUpdate(prizeType, 1, loopIndex, listForFirstPrize.length, listForFirstPrize);
  }

  function pickWinnerForSecond(uint256 prizeType) internal {
    uint256 loopIndex;
    bytes32 randomValue = randomnessForSecondPrize;
    require(randomValue != "", "Lottery: pending randomize");
    for (uint256 i = 0; i < TOTAL_PARTICIPATION; i++) {
      uint256 randomNumber = 1 + random(randomValue, i);
      if (winnerInfo[randomNumber] == 0) {
        winnerInfo[randomNumber] = 2;
        listForSecondPrize.push(randomNumber);
      }
      if (listForSecondPrize.length == TOTAL_SECOND_PRIZE) {
        loopIndex = i;
        break;
      }
    }
    emit WinnerListUpdate(prizeType, 1, loopIndex, listForSecondPrize.length, listForSecondPrize);
  }

  function pickWinnerForThird(uint256 prizeType) internal {
    uint256 loopIndex;
    bytes32 randomValue = randomnessForThirdPrize;
    require(randomValue != "", "Lottery: pending randomize");
    if (lists.length > 0) {
      delete (lists);
    }
    for (uint256 i = thirdIndex; i < TOTAL_PARTICIPATION; i++) {
      uint256 randomNumber = 1 + random(randomValue, i);
      if (winnerInfo[randomNumber] == 0) {
        winnerInfo[randomNumber] = 3;
        lists.push(randomNumber);
        listForThirdPrize.push(randomNumber);
      }
      if (listForThirdPrize.length % 100 == 0) {
        loopIndex = i;
        break;
      }
    }
    thirdIndex = loopIndex + 1;
    drawTimesForThirdPrize++;
    emit WinnerListUpdate(prizeType, drawTimesForThirdPrize, loopIndex, listForThirdPrize.length, lists);
  }

  function pickWinnerForFourth(uint256 prizeType) internal {
    uint256 loopIndex;
    bytes32 randomValue = randomnessForFourthPrize;
    require(randomValue != "", "Lottery: pending randomize");
    if (lists.length > 0) {
      delete (lists);
    }
    for (uint256 i = fourthIndex; i < TOTAL_PARTICIPATION; i++) {
      uint256 randomNumber = 1 + random(randomValue, i);
      if (winnerInfo[randomNumber] == 0) {
        winnerInfo[randomNumber] = 4;
        lists.push(randomNumber);
        listForFourthPrize.push(randomNumber);
      }
      if (listForFourthPrize.length % 100 == 0) {
        loopIndex = i;
        break;
      }
    }
    fourthIndex = loopIndex + 1;
    drawTimesForFourthPrize++;
    emit WinnerListUpdate(prizeType, drawTimesForFourthPrize, loopIndex, listForFourthPrize.length, lists);
  }
}

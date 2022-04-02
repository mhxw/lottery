// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitnetRandomness {
  /// Thrown every time a new WitnetRandomnessRequest gets succesfully posted to the WitnetRequestBoard.
  /// @param from Address from which the randomize() function was called.
  /// @param prevBlock Block number in which a randomness request got posted just before this one. 0 if none.
  /// @param witnetQueryId Unique query id assigned to this request by the WRB.
  /// @param witnetRequestHash SHA-256 hash of the WitnetRandomnessRequest actual bytecode just posted to the WRB.
  event Randomized(address indexed from, uint256 indexed prevBlock, uint256 witnetQueryId, bytes32 witnetRequestHash);

  /// Generates a pseudo-random number uniformly distributed within the range [0 .. _range), by using
  /// the given `_nonce` value and the randomness returned by `getRandomnessAfter(_block)`.
  /// @dev Fails under same conditions as `getRandomnessAfter(uint256)` may do.
  /// @param _range Range within which the uniformly-distributed random number will be generated.
  /// @param _nonce Nonce value enabling multiple random numbers from the same randomness value.
  /// @param _block Block number from which the search will start.
  function random(
    uint32 _range,
    uint256 _nonce,
    uint256 _block
  ) external view returns (uint32);

  /// Requests the Witnet oracle to generate an EVM-agnostic and trustless source of randomness.
  /// Only one randomness request per block will be actually posted to the WRB. Should there
  /// already be a posted request within current block, it will try to upgrade Witnet fee of current's
  /// block randomness request according to current gas price. In both cases, all unused funds shall
  /// be transfered back to the tx sender.
  /// @return _usedFunds Amount of funds actually used from those provided by the tx sender.
  function randomize() external payable returns (uint256 _usedFunds);

  /// Returns latest block in which a randomness request got sucessfully posted to the WRB.
  function latestRandomizeBlock() external view returns (uint256);
}

// File: contracts\examples\WitnetRandomness.sol
/// @title WitnetRandomness: A trustless randomness generator and registry, based on the Witnet oracle.
/// @author Witnet Foundation.
contract MockWitnetRandomness is IWitnetRandomness {
  uint256 public override latestRandomizeBlock;
  uint256 status;

  /// Generates a pseudo-random number uniformly distributed within the range [0 .. _range), by using
  /// the given `_nonce` value and the randomness returned by `getRandomnessAfter(_block)`.
  /// @dev Fails under same conditions as `getRandomnessAfter(uint256)` may do.
  /// @param _range Range within which the uniformly-distributed random number will be generated.
  /// @param _nonce Nonce value enabling multiple random numbers from the same randomness value.
  /// @param _block Block number from which the search will start.
  function random(
    uint32 _range,
    uint256 _nonce,
    uint256 _block
  ) external view virtual override returns (uint32) {
    require(status == 1, "WitnetRandomness: pending randomize");
    uint256 randomValue = uint256(keccak256(abi.encodePacked(abi.encode(msg.sender, _range, _nonce, _block)))) % _range;
    return uint32(randomValue);
  }

  /// Requests the Witnet oracle to generate an EVM-agnostic and trustless source of randomness.
  /// Only one randomness request per block will be actually posted to the WRB. Should there
  /// already be a posted request within current block, it will try to upgrade Witnet fee of current's
  /// block randomness request according to current gas price. In both cases, all unused funds shall
  /// be transfered back to the tx sender.
  /// @return _usedFunds Amount of funds actually used from those provided by the tx sender.
  function randomize() external payable virtual override returns (uint256 _usedFunds) {
    status = 1;
    if (latestRandomizeBlock < block.number) {
      uint256 _prevBlock = latestRandomizeBlock;
      latestRandomizeBlock = block.number;
      // Throw event:
      emit Randomized(msg.sender, _prevBlock, latestRandomizeBlock, "test");
      // Transfer back unused tx value:
      if (_usedFunds < msg.value) {
        payable(msg.sender).transfer(msg.value - _usedFunds);
      }
    }
  }
}

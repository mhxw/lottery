// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitnetRandomness {

  /// Retrieves the randomness generated upon solving a request that was posted within a given block,
  /// if any, or to the _first_ request posted after that block, otherwise. Should the intended
  /// request happen to be finalized with errors on the Witnet oracle network side, this function
  /// will recursively try to return randomness from the next non-faulty randomization request found
  /// in storage, if any.
  /// @dev Fails if:
  /// @dev   i.   no `randomize()` was not called in either the given block, or afterwards.
  /// @dev   ii.  a request posted in/after given block does exist, but no result has been provided yet.
  /// @dev   iii. all requests in/after the given block were solved with errors.
  /// @param _block Block number from which the search will start.
  function getRandomnessAfter(uint256 _block) external view returns (bytes32);

  /// Thrown every time a new WitnetRandomnessRequest gets succesfully posted to the WitnetRequestBoard.
  /// @param from Address from which the randomize() function was called.
  /// @param prevBlock Block number in which a randomness request got posted just before this one. 0 if none.
  /// @param witnetQueryId Unique query id assigned to this request by the WRB.
  /// @param witnetRequestHash SHA-256 hash of the WitnetRandomnessRequest actual bytecode just posted to the WRB.
  event Randomized(address indexed from, uint256 indexed prevBlock, uint256 witnetQueryId, bytes32 witnetRequestHash);

  /// Generates a pseudo-random number uniformly distributed within the range [0 .. _range), by using
  /// the given `_nonce` value and the given `_seed` as a source of entropy.
  /// @param _range Range within which the uniformly-distributed random number will be generated.
  /// @param _nonce Nonce value enabling multiple random numbers from the same randomness value.
  /// @param _seed Seed value used as entropy source.
  function random(uint32 _range, uint256 _nonce, bytes32 _seed) external pure returns (uint32);

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

  /// @dev Returns index of the Most Significant Bit of the given number, applying De Bruijn O(1) algorithm.
  function _msbDeBruijn32(uint32 _v)
  internal pure
  returns (uint8)
  {
    uint8[32] memory _bitPosition = [
    0, 9, 1, 10, 13, 21, 2, 29,
    11, 14, 16, 18, 22, 25, 3, 30,
    8, 12, 20, 28, 15, 17, 24, 7,
    19, 27, 23, 6, 26, 5, 4, 31
    ];
    _v |= _v >> 1;
    _v |= _v >> 2;
    _v |= _v >> 4;
    _v |= _v >> 8;
    _v |= _v >> 16;
    return _bitPosition[
    uint32(_v * uint256(0x07c4acdd)) >> 27
    ];
  }

  /// Retrieves the randomness generated upon solving a request that was posted within a given block,
  /// if any, or to the _first_ request posted after that block, otherwise. Should the intended
  /// request happen to be finalized with errors on the Witnet oracle network side, this function
  /// will recursively try to return randomness from the next non-faulty randomization request found
  /// in storage, if any.
  /// @dev Fails if:
  /// @dev   i.   no `randomize()` was not called in either the given block, or afterwards.
  /// @dev   ii.  a request posted in/after given block does exist, but no result has been provided yet.
  /// @dev   iii. all requests in/after the given block were solved with errors.
  /// @param _block Block number from which the search will start.
  function getRandomnessAfter(uint256 _block)
  public view
  virtual override
  returns (bytes32)
  {
    require(status == 1, "WitnetRandomness: pending randomize");
    return keccak256(abi.encodePacked(abi.encode(msg.sender, _block)));
  }

  /// Generates a pseudo-random number uniformly distributed within the range [0 .. _range), by using
  /// the given `_nonce` value and the given `_seed` as a source of entropy.
  /// @param _range Range within which the uniformly-distributed random number will be generated.
  /// @param _nonce Nonce value enabling multiple random numbers from the same randomness value.
  /// @param _seed Seed value used as entropy source.
  function random(uint32 _range, uint256 _nonce, bytes32 _seed)
  public pure
  virtual override
  returns (uint32)
  {
    uint8 _flagBits = uint8(255 - _msbDeBruijn32(_range));
    uint256 _number = uint256(
      keccak256(
        abi.encode(_seed, _nonce)
      )
    ) & uint256(2 ** _flagBits - 1);
    return uint32((_number * _range) >> _flagBits);
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

import { ethers } from 'hardhat'
import { assert, expect } from 'chai'
import { BigNumber, constants, Contract, ContractFactory, Signer } from 'ethers'
import { numToBytes32, publicAbi } from './test-helpers/helpers'
import { Personas, getUsers } from './test-helpers/setup'
import { bigNumEquals, evmRevert } from './test-helpers/matchers'

let personas: Personas
let defaultAccount: Signer

let mockWitnetRandomnessFactory: ContractFactory
let lotteryFactory: ContractFactory
let lottery: Contract
let mockWitnetRandomness: Contract

before(async () => {
  const users = await getUsers()

  personas = users.personas
  defaultAccount = users.roles.defaultAccount

  mockWitnetRandomnessFactory = await ethers.getContractFactory(
    'contracts/tests/MockWitnetRandomness.sol:MockWitnetRandomness',
    defaultAccount,
  )
  lotteryFactory = await ethers.getContractFactory(
    'contracts/LuckyDraw.sol:LuckyDraw',
    defaultAccount,
  )
})

describe('LuckyDraw', () => {
  const grandPrizeNum = 1
  const firstPrizeNum = 4
  const secondPrizeNum = 15
  const thirdPrizeNum = 200
  const fourthPrizeNum = 1000

  beforeEach(async () => {
    mockWitnetRandomness = await mockWitnetRandomnessFactory
      .connect(personas.Carol)
      .deploy()
    lottery = await lotteryFactory
      .connect(personas.Carol)
      .deploy(mockWitnetRandomness.address)
  })

  it('has a limited public interface [ @skip-coverage ]', () => {
    publicAbi(lottery, [
      'fetchRandomNumber',
      'pickWinner',
      'requestRandomNumber',
      'blockForLatestRandomizing',
      'blockForGrandPrize',
      'blockForFirstPrize',
      'blockForSecondPrize',
      'blockForThirdPrize',
      'blockForFourthPrize',
      'drawStatus',
      'getWinnerList',
      'getRandomNumber',
      'winnerInfo',
      'isFinished',
      'randomnessForGrandPrize',
      'randomnessForFirstPrize',
      'randomnessForSecondPrize',
      'randomnessForThirdPrize',
      'randomnessForFourthPrize',
      'requestRandomNumber',
      'witnet',
      // Owned methods:
      'renounceOwnership',
      'owner',
      'transferOwnership',
    ])
  })

  describe('#constructor', () => {
    it('sets the witnet', async () => {
      assert.equal(mockWitnetRandomness.address, await lottery.witnet())
    })

    it('sets the owner', async () => {
      assert.equal(await personas.Carol.getAddress(), await lottery.owner())
    })

    it('set zero addr', async () => {
      await expect(
        lotteryFactory.connect(personas.Carol).deploy(constants.AddressZero),
      ).to.be.revertedWith('Lottery: the witnet is the zero address')
    })
  })

  describe('#getRandomNumber', () => {
    it('not request and fetch', async () => {
      await evmRevert(
        lottery.connect(personas.Carol).getRandomNumber(0),
        'Lottery: pending randomize',
      )
    })
  })

  describe('#pickWinner', () => {
    it('the fourth prize has not been drawn', async () => {
      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(3),
        'Lottery: the fourth prize has not been drawn',
      )
    })

    it('pending randomize', async () => {
      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(4),
        'Lottery: pending randomize',
      )
    })
  })

  describe('#requestnumber', () => {
    it('request random number not value', async () => {
      await evmRevert(
        lottery.connect(personas.Carol).requestRandomNumber(4),
        'Lottery: the value must be greater than zero',
      )
    })

    it('request random number of err number', async () => {
      await evmRevert(
        lottery
          .connect(personas.Carol)
          .requestRandomNumber(3, { value: ethers.utils.parseEther('0.5') }),
        'Lottery: it is not yet the turn of the third prize operation or the third prize has been operated',
      )
    })

    it('not randomness', async () => {
      await evmRevert(
        lottery
          .connect(personas.Carol)
          .requestRandomNumber(3, { value: ethers.utils.parseEther('0.5') }),
        'Lottery: it is not yet the turn of the third prize operation or the third prize has been operated',
      )
    })

    it('request random number success', async () => {
      await evmRevert(
        lottery
          .connect(personas.Carol)
          .requestRandomNumber(0, { value: ethers.utils.parseEther('0.5') }),
        'Lottery: it is not yet the turn of the grand prize operation or the grand prize has been operated',
      )

      await evmRevert(
        lottery
          .connect(personas.Carol)
          .requestRandomNumber(1, { value: ethers.utils.parseEther('0.5') }),
        'Lottery: it is not yet the turn of the first prize operation or the first prize has been operated',
      )

      await evmRevert(
        lottery
          .connect(personas.Carol)
          .requestRandomNumber(2, { value: ethers.utils.parseEther('0.5') }),
        'Lottery: it is not yet the turn of the second prize operation or the second prize has been operated',
      )

      const tx = await lottery
        .connect(personas.Carol)
        .requestRandomNumber(4, { value: ethers.utils.parseEther('0.5') })

      const block = await ethers.provider.getBlock(tx.blockHash ?? '')

      assert.equal(await lottery.blockForFourthPrize(), block.number)

      for (let i = 3; i >= 0; i--) {
        await lottery
          .connect(personas.Carol)
          .requestRandomNumber(i, { value: ethers.utils.parseEther('0.5') })
      }

      for (let i = 4; i >= 0; i--) {
        await lottery.connect(personas.Carol).fetchRandomNumber(i)
      }

      const randomValue = await lottery.getRandomNumber(4)
      assert.equal(
        BigNumber.from(await lottery.randomnessForFourthPrize()).toNumber,
        BigNumber.from(randomValue).toNumber,
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(0),
        'Lottery: the first prize has not been drawn',
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(1),
        'Lottery: the second prize has not been drawn',
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(2),
        'Lottery: the third prize has not been drawn',
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(3),
        'Lottery: the fourth prize has not been drawn',
      )

      assert.equal(await lottery.isFinished(4), false)
      assert.equal(await lottery.drawStatus(), 4)
      for (let i = 0; i < 10; i++) {
        await lottery.connect(personas.Carol).pickWinner(4)
      }
      assert.equal(await lottery.isFinished(4), true)

      assert.equal(await lottery.isFinished(3), false)
      assert.equal(await lottery.drawStatus(), 3)
      for (let i = 0; i < 2; i++) {
        await lottery.connect(personas.Carol).pickWinner(3)
      }
      assert.equal(await lottery.isFinished(3), true)

      assert.equal(await lottery.isFinished(2), false)
      assert.equal(await lottery.drawStatus(), 2)
      await lottery.connect(personas.Carol).pickWinner(2)
      assert.equal(await lottery.isFinished(2), true)

      assert.equal(await lottery.isFinished(1), false)
      assert.equal(await lottery.drawStatus(), 1)
      const pickWinner1Tx = await lottery.connect(personas.Carol).pickWinner(1)
      await expect(pickWinner1Tx)
        .to.emit(lottery, 'WinnerListUpdate')
        .withArgs(1, 1, 3, firstPrizeNum, await lottery.getWinnerList(1))
      assert.equal(await lottery.isFinished(1), true)

      assert.equal(await lottery.isFinished(0), false)
      assert.equal(await lottery.drawStatus(), 0)
      const pickWinner0Tx = await lottery.connect(personas.Carol).pickWinner(0)
      await expect(pickWinner0Tx)
        .to.emit(lottery, 'WinnerListUpdate')
        .withArgs(0, 1, 0, grandPrizeNum, await lottery.getWinnerList(0))
      assert.equal(await lottery.isFinished(0), true)
      assert.equal(await lottery.drawStatus(), 5)
      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(4),
        'Lottery: the prize has been drawn out',
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(3),
        'Lottery: the prize has been drawn out',
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(2),
        'Lottery: the prize has been drawn out',
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(1),
        'Lottery: the prize has been drawn out',
      )

      await evmRevert(
        lottery.connect(personas.Carol).pickWinner(0),
        'Lottery: the prize has been drawn out',
      )
    })
  })
})

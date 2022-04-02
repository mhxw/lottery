# Lottery

- install

```
yarn install
```

- test

```
yarn test
```

- flatten

```
mkdir flat
npx hardhat flatten <path-to-contract> >> <flat-contract-name>.sol
npx hardhat flatten contracts/LuckyDraw.sol >> flat/LuckyDraw.sol
```
# Space creation

_**We are working on the visual constructor right now. But for upgradable versions you need to use this manual anyway**_

To create space you need to deploy 3 contracts

```shell
1. Space
2. Timelock
3. Governor
```

Each of these contracts can be deployed as upgradable or non-upgradable version

## Prerequisites (for upgradable version)

For upgradable version you need to install hardhat first

```shell
<Instal NPM for your system>
npm install --save-dev hardhat
npm install
```

After add to `hardhat.config.js` your private key
```shell
networks: {
       mainnet: {
            url: `https://rpc.ankr.com/eth` (for example),
            gasPrice: 80000000000,
            accounts: [
                `<your private key>`
            ]
        }
}
```
Don't forget to adjust gas price. As deployment takes time.

## Storage configuration
Upload json files for each attribute to your storage. 
Names should be like _1.json_, _2.json_, _3.json_ etc.

Also upload _space.json_ which define space description with same structure.

Use following structure:
```shell
{
  "name": string,
  "description": string,
  "image": string (full path to the image)
}
```

## Deploying space

### Upgradable version

Go to _scripts/deploy-space-upgradable.js_ and change uri placeholder to url prefix to you storage.

**!!Dont forget to add '/' symbol at the end**

For example for Lasrever all files are uploaded into https://s3.eu-central-1.wasabisys.com/theanima/attributes/ folder.

Then you can simply run

`npx hardhat --network mainnet run scripts/deploy-space-upgradable.js`

You will get 3 contracts after this. 

### Non upgradable version

```shell
1. Deploy SpaceNonUpgradable.sol contract and provide 
    Uri, Name and address to Soulbound (0x7d1ec0085368842747d47bb444eee88d08c7419a)

2. Deploy Timelock from here https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol

3. Deploy SoulboundGovernorNonUpgradable.
    Provide Space Address and Timelock Address
```

### Adding attributes
You just need to call _addAttribute_ method on space contract.
You need to define 3 parameters:
1. **Id**, which will be using for getting json file with attribute definition
2. **Burn Amount in wei**, how much of coin will be burned during transactions. Note that this value is provided in ETH. So it depends on the price how much tokens will be burned.
3. **Supply**, how much attributes can be minted. Provide **0** for unlimited

Space will appear in dapp shortly. If not please contact with us by email reversal@lasrever.io

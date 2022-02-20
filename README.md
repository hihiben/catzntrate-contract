# Catzntrate

This project is a project for ETHDenver 2022 hackathon. Let's concentrate and buidl!
Catz'ntrate is the application to help you concentrate on a task. Whether you want to learn a new language, a new skill, focus on your coding, or just finish your homework, catzentrate helps to gamify completing your task by removing external distractions to focus on being productive.

Owners of the Catzntrate nft pets will be able to earn the CFT token by activating the concentrate mode and focusing on a task for 25 minutes per round. Each nft pet will have enough energy per day for 2 rounds, or 60 minutes on concentration. 

## Structure

The contract system is divided into several components, including the NFT, ERC20 token, and the main contract.

### NFT

#### CATZ

The pet system is implemented through the ERC721 standard. Each Catz has its own gene, which will then effect the stats in Catzntrate.

### ERC20

There are three different ERC20 token contract implemented for different purpose.

#### CFT

CFT is the main token in the game, which can be used to level up, buy food ...etc. Your pet can earn you CFT after working and petting them.

#### CGT

CGT is the governance token, which can also be used in the premium features. User may choose to mint CGT or CFT after working.

#### CF

CatFood can be used to prevent Catz from starving.

## Attribute

There are four attributes to represent the most important characteristics for the people in crypto world.

### Efficiency

Improves the profits getting from working.

### Curiosity

Increases the possibility of going on an adventure.

### Luck

Increase the possibility of getting better items in the adventure.

### Vitality

Decrease the consuming speed of food.

## Energy and saturation

Catz must have both engergy and saturation to work. Saturation can only be added by eating CatFood. Enery is refilled by 9 every morning.

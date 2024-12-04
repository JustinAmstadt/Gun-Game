# Set Up Gun Game in Move

## Set up Sui if you haven’t already

Install Sui: https://docs.sui.io/guides/developer/getting-started/sui-install

Set environment to Testnet:

If just starting out, make a new environment:

```jsx
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
```

If you already have it, switch to it. Use whatever alias you set for the testnet

Get your alias name if you forgot it:

```bash
sui client envs
```

```bash
sui client switch --env testnet # OR whatever alias name you set for testnet
```

Make key:

```bash
sui client new-address ed25519 main-key
```

Get gas:

```bash
sui client faucet
```

Get private key:

```bash
sui keytool export --key-identity main-key
```

The private key should start with suiprivkey…

## Code Location

It is currently a PR right now:
https://github.com/Parasol-App/parasol-sui/pull/32

Find the code in parasol-sui/examples/gun-game

## Node Version

Install nvm:

```bash
nvm use 20
```

Or set up your environment to use node version 20.

I specifically am using v20.12.2

## Set up the environment variables in the gun game:

.env file:

```bash
RPC_URL=https://fullnode.testnet.sui.io:443
NFT_PACKAGE_ID= # Publish the move package

GAME_MASTER_CAP= # For contract publisher only. A normal user doesn't need access to this object
GAME_OBJECT= # Given to the address that publishes the package

# These can both be the same key, but the difference is the first one is the sponsor key and the second one is one that is actually registered in the game
SECRET_KEY= 
SECOND_SECRET_KEY= 

PLAYER_NAME= # Set it to whatever you want!
```

## Run the Game

In the gun-game directory, run both `npx ts-node src/main.ts`  and `npx ts-node src/render-game.ts` in separate terminals

When you first run the `main.ts` file, look for a print statement that tells you which team you are on. It will either be 0 which is team 1 or 1 for team 2

The commands are as follows:

```bash
Move left: l
Move right: r
Move u: u
Move down: d
Shoot left: sl
Shoot right: sr
Shoot up: su
Shoot down: sd
```

You and your teammates will queue commands for your team’s player and the game state updates when both teams have a move queued

The command input is async, so feel free to spam it!

## Game Explanation

```
& * * * * * * 
* # * * * * * 
* * * * * # * 
* * * * * # * 
* * * # * * * 
* * * * * # * 
* * * * * * & 
```

Team 1’s starting position is on the top left while team 2’s is on the bottom right

* is a normal tile that can be moved to

* is a wall that cannot be moved onto or shot through

When a team successfully shoots the other team’s player, the shot player will show up as an X

There is no graphical representation for shots

Shots go until they hit a wall, the edge of the map, or a player

## On Game Over

Once a game is over, the winning team gets an NFT and everyone gets kicked from the game and the command queues are emptied

Run `main.ts` again and you may or may not be on the same based on the order everyone joins
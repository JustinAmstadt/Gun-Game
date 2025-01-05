# Gun Game: An Example in Sui On Chain Games Part 1

As blockchain technology matures and new players emerge, one blockchain has really stuck out in the year of 2024: Sui. Emerging as a newer blockchain, Sui gives a *mind-opening* way of looking at and using blockchains, and is a complete game-changer for game developers who wish to implement a game completely on-chain.

## Why Would I Want to Make a Game on Sui Anyways?

As many developers know, managing a server on the backend can be a lot of work as your game/tool grows in popularity. Additionally, as long as the blockchain is secure, your game is secure with no concern for hackers. The best part though? Your game will last forever with **no management required**! While you may be convinced on why you would use blockchain for game development, you may still be wondering what's special about Sui. I'll give that answer to you in one word: **objects**.

Sui programming revolves around objects. It is very easy to make objects and wallets can own objects. These objects can be *anything*, including NFTs, game objects and more! Anything from game states to in-game items can all use Sui's object system, making it a **much more robust system for games.**

If you still have questions such as to how *exactly* Sui is good for games and more importantly, **how to make something in Sui**, then look no further!

## The Goal

My goal over these next few articles is to show you how to build a game starting from zero prior experience in Sui to a full-blown game on the testnet. I will focus *only* on **Mac** and **Linux** users, but it is important to note that Sui **does support Windows users**.

Here is the roadmap:
- Setting up your environment *
- Making the game state in Move
- Making the game logic in Move
- Testing the game
- Writing Typescript code to interface with the blockchain

## Let's Get Started with Setting Up Your Environment!

It is important to note that I will be giving my own guide for setup, but I will also be linking the [official guide](https://docs.sui.io/guides) along the way. My guide is a streamlined, easy to understand version of the existing docs, but please refer to them if you are having issues.

If you are already familiar with Sui, you can skip this part and move onto the next part.

## How to Install the Sui CLI

If you already have brew installed on your system, just run this command:

```bash
brew install sui
```

If not, **here is how to install brew**:

For mac users use this:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

For linux users use this:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install build-essential curl file git -y
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>~/.bashrc
source ~/.bashrc
```

Now, run this to test that you installed correctly:

```bash
brew --version
```

You should get something similar to this:

```
Homebrew 4.4.14
```

Now just run the above sui install command above.

Here is the [installation page](https://docs.sui.io/guides/developer/getting-started/sui-install) in the Sui docs for those who need more information.

There is a *lot* in this CLI, but I will break things down for you step-by-step.

## Setting up the Network Environment and Keypair

With a fresh install, just type this command and you will be prompted through the environment and keypair creation.

```bash
sui client
```

Sample Output:

```
sui client
Config file ["/home/justin/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?y
Sui Full node server URL (Defaults to Sui Testnet if not specified) : 
Select key scheme to generate keypair (0 for ed25519, 1 for secp256k1, 2: for secp256r1):
0
Generated new keypair and alias for address with scheme "ed25519" [Your keypair]
Secret Recovery Phrase : [Your recovery phrase]
Client for interacting with the Sui network
```

Now we will test to make sure we did everything correctly:

```bash
sui client envs
```

Should return:

```
╭─────────┬─────────────────────────────────────┬────────╮
│ alias   │ url                                 │ active │
├─────────┼─────────────────────────────────────┼────────┤
│ testnet │ https://fullnode.testnet.sui.io:443 │ *      │
╰─────────┴─────────────────────────────────────┴────────╯
```

and

```bash
sui client addresses
```

Should return:

```
╭────────────┬────────────────────────────────────────────────────────────────────┬────────────────╮
│ alias      │ address                                                            │ active address │
├────────────┼────────────────────────────────────────────────────────────────────┼────────────────┤
│ ALIAS-NAME │ YOUR ADDRESS                                                       │ *              │
╰────────────┴────────────────────────────────────────────────────────────────────┴────────────────╯
```

This can also be seen in the [official guide](https://docs.sui.io/guides/developer/getting-started/connect).

## Conclusion

With that, you should be set up for the next part in the series!

Developing on the Sui blockchain can feel challenging at first, but there are many powerful features that you will see in future parts that makes Sui a solid choice for game development!
# Gun Game: An Example in Sui On Chain Games Part 3

This is part 3 of the series, so check out part 1 if you are new.

In the last part we made the `Game` object that hold our game state information. In this part we will focus on player management to let a player join, leave, and be kicked from the game.

## Roadmap

Here is our roadmap that we are following:
- Setting up your environment
- Making the game state in Move
- Adding the player management logic in Move *
- Adding character movement and shooting in the game
- Adding end game logic
- Testing the game
- Writing Typescript code to interface with the blockchain

## Events

Before we go any further, we should talk about events. Events are a commonly available tool on blockchains to give more information to programmers interfacing with a contract. In Sui, **events are simply a matter of creating an object.**

Here's an example:

```move
use sui::event; // Add event module import

// All events must have the copy and drop abilities. This event can be any name and have any kind of information you want
public struct MyEvent has copy, drop {
    eventInformation1: String,
    eventInformation2: u64,
    eventInformation3: address
}

...

public fun emitEvent(info1: String, info2: u64, info3: address) {
    // Create the event like any other object
    let event = MyEvent {
        eventInformation1: info1,
        eventInformation2: info2,
        eventInformation3: info3
    };

    // Emit the event
    event::emit(event);
}
```

More on events [here](https://move-book.com/programmability/events.html).

With an intro to events out of the way, we have one more concept to introduce.

## Asserts and Error Codes

Asserts are a common idea in other programming languages, so I will keep this brief.

If an assert fails in the contract, the code will abort with an error code that you specify. This is critical for error checking and ensuring proper behavior when others are interacting with your contract.

Here's an example:

```move
// Yes, errors are just a u64!
const EIncorrectVal: u64 = 0;

...

public fun someFun(val: u64) {
    assert!(val == 10, EIncorrectVal);
}
```

With these two important concepts out of the way, let's get into the next part: **player management.**

## Joining, Leaving, and Kicking

For any online game, these are 3 important actions that must be implemented for a smooth experience. We will go through these one by one.

But first, add some constants to your code:

```move
// === Constants ===

...

const TEAM_1: u64 = 0;
const TEAM_2: u64 = 1;
```

### Joining

This next snippet of code will add a `PlayerJoined` event, a new error code, and a function for joining a game.

```move
use sui::event;

...

// === Events ===

...

public struct PlayerJoined has copy, drop {
    playerName: string::String, // Player name that the player chooses
    playerAddress: address, // Address that the player is using to make transactions
    team: u64 // The team the player was assigned to
}

...

// === Errors ===

...

const EPlayerAlreadyInGame: u64 = 1;

...

// === Functions ===

...

// game: A shared object that anyone can access and contains all data related to the game state
// name: The name the player wants to be known as
// ctx: The transaction context
public fun join_game(game: &mut Game, name: string::String, ctx: &mut TxContext) {
    // This assert check the VecMap of players to make sure this address isn't already in the game. Fail with EPlayerAlreadyInGame if vec_map::contains returns true
    assert!(!vec_map::contains(&game.players, &ctx.sender()), EPlayerAlreadyInGame);

    // Make a player variable
    let player: Player;

    // Checks if team1 has more players than team 2
    if (game.team1_player_count > game.team2_player_count) {
        // Make the player object
        player = Player {
            name: name,
            address: ctx.sender(),
            team: TEAM_2
        };

        // Increment the team 2 player count
        game.team2_player_count = game.team2_player_count + 1;
    } else {
        // Make the player object
        player = Player {
            name: name,
            address: ctx.sender(),
            team: TEAM_1
        };

        // Increment the team 1 player count
        game.team1_player_count = game.team1_player_count + 1;
    };

    // Make the PlayerJoined event
    let event = PlayerJoined {
        playerName: name,
        playerAddress: ctx.sender(),
        team: player.team
    };

    // Emit the event
    event::emit(event);

    // Add the name player to the VecMap to ensure they can't rejoin the game
    game.players.insert(ctx.sender(), player);
}

...
```

We have already talked about many of the methods that are used here, so this function is hopefully not too difficult to understand.

### Leaving

Similar to joining, this next snippet will feature a new event, error code, and function for a player leaving mid-game.

```move
// === Events ===

...

// This is the same data as PlayerJoined
public struct PlayerLeft has copy, drop {
    playerName: string::String,
    playerAddress: address,
    team: u64
}

...

// === Errors ===

...

const EPlayerNotInGame: u64 = 0;

...

// === Functions ===

...

public fun leave_game(game: &mut Game, ctx: &mut TxContext) {
    // This assert statement is the opposite of the previous one. A player must already be in the game in order to leave it.
    assert!(vec_map::contains(&game.players, &ctx.sender()), EPlayerNotInGame);

    // Here is the syntax for removing from a VecMap. The syntax _key means that we are getting the value returned, but we don't plan on using it
    let (_key, player) = vec_map::remove(&mut game.players, &ctx.sender());

    // Decrement from the team the player was on
    if (player.team == TEAM_1) {
        game.team1_player_count = game.team1_player_count - 1;
    } else {
        game.team2_player_count = game.team2_player_count - 1;
    };

    // Create event
    let event = PlayerLeft {
        playerName: player.name,
        playerAddress: ctx.sender(),
        team: player.team
    };

    // Emit event
    event::emit(event);
}
```

### Kicking

Kicking is similar to both joining and leaving, so I will get straight into the code.

```move
// === Events ===

...

public struct PlayerKicked has copy, drop {
    playerName: string::String,
    playerAddress: address,
    team: u64
}

...

// Functions

...

// It is important to note that this function doesn't actually use the GameMasterCap, but accepting it in makes kick_player an admin only function
public fun kick_player(_: &GameMasterCap, game: &mut Game, playerAddress: address) {
    // Same assertion as leave_game to make sure the player is actually in the game
    assert!(vec_map::contains(&game.players, &playerAddress), EPlayerNotInGame);

    // Remove the player from the VecMap
    let (_key, player) = vec_map::remove(&mut game.players, &playerAddress);

    // Decrement player count from the team they were on
    if (player.team == TEAM_1) {
        game.team1_player_count = game.team1_player_count - 1;
    } else {
        game.team2_player_count = game.team2_player_count - 1;
    };

    // Make event
    let event = PlayerKicked {
        playerName: player.name,
        playerAddress: playerAddress,
        team: player.team
    };

    // Emit event
    event::emit(event);
}
```

## Conclusion

Now that players can join and leave the game, we need to make sure there is something for them to do. We have both the **game state** and the **players in the game**, so now it is time to change the game state with two actions: **moving and shooting.**
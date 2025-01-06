# Gun Game: An Example in Sui On Chain Games Part 6

This is part 6 of the series, so check out part 1 if you are new.

Now that our game has a game state and players can join, we need to make sure players can do things in the game. 

## Roadmap

Here is our roadmap that we are following:
- Setting up your environment
- Making the game state in Move
- Adding the player management logic in Move
- Adding character movement and shooting in the game
- Adding player control over the character
- Adding end game logic *
- Testing the game
- Writing Typescript code to interface with the blockchain

## Final Objects and Errors Needed

To cover the last of the code, we need to add objects related to minting a new NFT and the final error code.

```move
// === Structs ===

...

// This is the actual NFT to be minted
public struct GameResult has key, store {
    id: UID,
    name: string::String,
    message: string::String
}

...

// === Events ===

...

public struct GameOutcomeMinted has copy, drop {
    objectAddress: address,
    playerName: string::String,
    playerAddress: address
}

...

// === Errors ===

...

const ETeamDoesNotExist : u64 = 3;

...
```

## Final Functions to Add

We will start with the simplest code that has to do with queue mangement. When a game is over, we don't want the move queue to contain moves from the last game so we must have a function that empties both queues.

```move
// game: We are changing a value that game has, so it must be mut
fun empty_queues(game: &mut Game) {
    while (!is_queue_empty(game, TEAM_1)) {
        // Pop the value without using it
        game.teams[TEAM_1].move_queue.pop_max<u64>();
    };
    while (!is_queue_empty(game, TEAM_2)) {
        game.teams[TEAM_2].move_queue.pop_max<u64>();
    };
}
```

We will now handle the minting function. Minting is a very common operation, so pay close attention if you aren't familiar with how to do it in Sui Move.

```move
fun mint_game_result(game: &mut Game, winning_team: u64, ctx: &mut TxContext) {
    // Ensure that a valid winning_team is chosen
    assert!(winning_team == TEAM_1 || winning_team == TEAM_2, ETeamDoesNotExist);

    // Pop each player from the VecMap. This will take care of two things: Kicking each player after the game over and giving the player an NFT if they were on the winning team
    while (!game.players.is_empty()) {
        // Since this is a VecMap, we get both the key and value here, but we only use the value so "_" is added to the "key" variable
        let (_key, player) = game.players.pop();

        // Skip minting logic if the player was on the losing team
        if (player.team != winning_team) {
            continue
        };

        // Make the NFT object
        let gameResult = GameResult {
            id: object::new(ctx),
            name: player.name,
            message: string::utf8(b"You won the game!")
        };

        // Make the event
        let event = GameOutcomeMinted {
            objectAddress: object::id_to_address(&object::id(&gameResult)), // This gets the object id of the newly minted NFT. This is the value that can be looked on later
            playerAddress: player.address,
            playerName: player.name
        };

        // Emit the event
        event::emit(event);

        // Transfer the object to the player's address
        transfer::public_transfer(gameResult, player.address);
    }
}
```

We will now use these new functions in our long awaited `game_over` function. This function will call the minting function, tell the game to reset the grid on the next move, and empty the move queues.

```move
fun game_over(game: &mut Game, winning_team: u64, ctx: &mut TxContext) {
    mint_game_result(game, winning_team, ctx);
    game.reset_grid = true; // Used in the play_game function to check if the game needs to be reset
    empty_queues(game);
}
```

## Conclusion

6 parts later and we finally finished our game! There was a lot to it, but hopefully you are a bit more comfortable than you first were. I hope that you can use this example as a reference when you are writing your own contract!
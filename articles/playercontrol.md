# Gun Game: An Example in Sui On Chain Games Part 5

This is part 5 of the series, so check out part 1 if you are new.

Now that our game has a game state and players can join, we need to make sure players can do things in the game. 

## Roadmap

Here is our roadmap that we are following:
- Setting up your environment
- Making the game state in Move
- Adding the player management logic in Move
- Adding character movement and shooting in the game
- Adding player control over the character *
- Adding end game logic
- Testing the game
- Writing Typescript code to interface with the blockchain

## Clarifying How the Game Works

Before we continue with the code, I want to make it clear how we want the game to be played.

There are two actions the characters on each team can do: Move and shoot. Now, how do we manage multiple human players controlling on in-game character? **We use a move queue.**

Now, it is also important to know that **the game only progresses when the characters on both teams have a move queued.** If one team keeps entering moves into their queue, but the other team's move queue is empty, the game will *not* progress.

## Constants, Events, and Errors!

You should know the drill at this point.

The constants are all integers that are used to denote which move the player would like to do. Again, they will make the code easier to understand.

```move
const MOVE_LEFT: u64 = 0;
const MOVE_RIGHT: u64 = 1;
const MOVE_UP: u64 = 2;
const MOVE_DOWN: u64 = 3;

const SHOOT_LEFT: u64 = 4;
const SHOOT_RIGHT: u64 = 5;
const SHOOT_UP: u64 = 6;
const SHOOT_DOWN: u64 = 7;
```

Here is the event we need. This event will be emitted every time a player makes a move.

```move
public struct GamePlayed has copy, drop {
    playerName: string::String,
    playerAddress: address,
    player_choice: u64
}
```

Finally, our error is to ensure the player made a valid input. We will use this whenever a player tries to input a value other than those listed in the constants above.

```move
const EInvalidInput: u64 = 2;
```

# Queue Helper Function

We will be using another helper function to increase readability in our code. This function will return a boolean value based on whether or a queue is empty.

```move
fun is_queue_empty(game: &Game, team: u64): bool {
    game.teams[team].move_queue.priorities().is_empty()
}
```

# TODO: Move the correct move assertion check to the new spot
## Parsing a Player's Action

This is a simple function that routes to the correct function based on the player's input and errors if the input is incorrect.

```move
// game: Must be &mut because all the functions that it is passed to requires it to be.
fun player_action(game: &mut Game, team: u64, player_choice: u64, ctx: &mut TxContext) {
    if (player_choice == MOVE_LEFT) {
        move_left(game, team);
    } else if (player_choice == MOVE_RIGHT) {
        move_right(game, team);
    } else if (player_choice == MOVE_UP) {
        move_up(game, team);
    } else if (player_choice == MOVE_DOWN) {
        move_down(game, team);
    } else if (player_choice == SHOOT_LEFT) {
        shoot_left(game, team, ctx);
    } else if (player_choice == SHOOT_RIGHT) {
        shoot_right(game, team, ctx);
    } else if (player_choice == SHOOT_UP) {
        shoot_up(game, team, ctx);
    } else if (player_choice == SHOOT_DOWN) {
        shoot_down(game, team, ctx);
    };
}
```

This function is just taking advantage of the code we already wrote in the last part.

## The Entry Keyword

As a quick aside, we will be using the `entry` keyword very soon, so let's discuss it.

Here's an example usage of `entry`:

```move
entry fun my_fun() {}
```

An `entry` function cannot be called from another Move function and must be the first call in a programmable transaction block. More on entry [here](https://docs.sui.io/concepts/sui-move-concepts/entry-functions).

`entry` functions are very useful when making a function that does randomness because it restricts how that function can be used. More on that [here](https://docs.sui.io/guides/developer/advanced/randomness-onchain#use-non-public-entry-functions). This is exactly what we will be doing in the next snippet of code!

## The Play Game Function

Finally we made it! This is the function players have access to when they want to make a move in the game after they have joined the game.

There is a *lot* going on in the next function handle all the bits of logic when a player makes a move, but I'll explain it all.

```move
// game: Must be &mut because player_action requires it to be
// player_choice: The integer that will be inserted into the move queue
// r: The Random variable that will be used if the game needs to reset
// ctx: The transaction context
entry fun play_game(game: &mut Game, player_choice: u64, r: &Random, ctx: &mut TxContext) {
    // An assert to make sure the player is in the game
    assert!(vec_map::contains(&game.players, &ctx.sender()), EPlayerNotInGame);

    // An assert to make sure the move is valid. If an invalid move entered in the queue, it could break the game
    assert!(
        player_choice == MOVE_LEFT || 
        player_choice == MOVE_RIGHT || 
        player_choice == MOVE_UP || 
        player_choice == MOVE_DOWN ||
        player_choice == SHOOT_LEFT ||
        player_choice == SHOOT_RIGHT ||
        player_choice == SHOOT_UP ||
        player_choice == SHOOT_DOWN,
        EInvalidInput
    );

    // When a game over happens, the reset_grid value will be set to true and the whole game is reset
    if (game.reset_grid) {
        // Reset the reset_grid value to false
        game.reset_grid = false;

        // Make a new grid. This is where our Random variable is used. Even if someone tried to manipulate randomness in our game, it is low risk anyways since we are only using randomness to reposition walls. Better to follow guidelines though
        game.grid = make_grid(game.grid_size, 0, 0, game.grid_size - 1, game.grid_size - 1, r, ctx);

        // Reset character positionings
        vector::borrow_mut(&mut game.teams, TEAM_1).controllable_character.x = 0;
        vector::borrow_mut(&mut game.teams, TEAM_1).controllable_character.y = 0;
        vector::borrow_mut(&mut game.teams, TEAM_2).controllable_character.x = game.grid_size - 1;
        vector::borrow_mut(&mut game.teams, TEAM_2).controllable_character.y = game.grid_size - 1;
    };

    // Look up the player in the VecMap to see which team they are on. "team" is an integer that will be used to index into the game.teams field
    let team = vec_map::get(&game.players, &ctx.sender()).team;

    // Set the enemy team to a value, but make it mutable if we need to change it
    let mut enemy_team = TEAM_1;

    // If the team the player making a move is actually team 1, change the enemy team to team 2
    if (team == TEAM_1) {
        enemy_team = TEAM_2;
    };

    // Index into the game.teams vector to insert a move into the 
    game.teams[team].move_queue.insert<u64>(1, player_choice);

    // Since the game only progresses if both teams have a move queued, we return before any moves are played if the enemy team doesn't have a move queued yet
    if (is_queue_empty(game, enemy_team)) {
        return
    };

    // Get the next value of the queue from both teams. pop_max will return both the priority of the value it returns and the actual value stored. Since all priorities are the same for us, we use "_" to signify that we won't be using it
    let (_priority_team, next_move_team) = game.teams[team].move_queue.pop_max<u64>();
    let (_priority_enemy_team, next_move_enemy_team) = game.teams[enemy_team].move_queue.pop_max<u64>();

    // Check to see if either team is shooting to use for logic later
    let is_team_shoot = next_move_team >= SHOOT_LEFT;
    let is_enemy_team_shoot = next_move_enemy_team >= SHOOT_LEFT;

    // Make a new event
    let event = GamePlayed {
        playerName: game.players.get(&ctx.sender()).name,
        playerAddress: ctx.sender(),
        player_choice: player_choice
    };

    // Emit the event
    event::emit(event);

    // This logic determines who goes first based on whether or not a team is shooting or not. Always let the team that is moving go first if the other is shooting. If both teams are shooting then the move cancels and nothing happens
    if (is_team_shoot && !is_enemy_team_shoot) {
        player_action(game, enemy_team, next_move_enemy_team, ctx);
        player_action(game, team, next_move_team, ctx);
    } else if (is_enemy_team_shoot && !is_team_shoot) {
        player_action(game, team, next_move_team, ctx);
        player_action(game, enemy_team, next_move_enemy_team,  ctx);
    } else if (!is_team_shoot && !is_enemy_team_shoot) {
        player_action(game, team, next_move_team, ctx);
        player_action(game, enemy_team, next_move_enemy_team, ctx);
    }
}
```

## Conclusion

With the player logic done, we can play a full game, but we need to reset the game when the game is over. Remember that `game_over` function? We will be using that in the next part to reset the game and even give the players on the winning team a goodie.
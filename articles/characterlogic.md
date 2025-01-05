# Gun Game: An Example in Sui On Chain Games Part 4

This is part 4 of the series, so check out part 1 if you are new.

Now that our game has a game state and players can join, we need to make sure players can do things in the game. 

## Roadmap

Here is our roadmap that we are following:
- Setting up your environment
- Making the game state in Move
- Adding the player management logic in Move
- Adding character movement and shooting in the game *
- Adding player control over the character
- Adding end game logic
- Testing the game
- Writing Typescript code to interface with the blockchain

## Character Movement

This part will focus only on the character movement and we will give human players control over the characters in the next part.

## Helper Functions and More

Before we get into the main functions, let's add a couple of helper functions for increased readability.

```move 
fun is_wall(game: &Game, x: u64, y: u64): bool {
    game.grid[y][x] == WALL
}

fun is_character(game: &Game, x: u64, y: u64): bool {
    game.grid[y][x] == CHARACTER
}
```

I assume this is apparent what is going on here, but I will note that `game: &Game` means that we are passing in the value, but we are only reading from it.

We also need to add an empty `game_over` function for now. We will fill it out later, but we need it to make sure the functions up ahead compile.

```move
fun game_over(game: &mut Game, winning_team: u64, ctx: &mut TxContext) {
}
```

Finally, we need to add another constant for the final ascii value we will be using. This value is signify that a character has died and will replace the normal character with an "X".

```move
...

// === Constants

...

const X: u8 = 88;

...
```

## Movement Functions

There are four movement functions for each direction, so I will only explain one, but give all four.

```move
fun move_left(game: &mut Game, team: u64) {
    // This nasty syntax borrows the controllable character from the teams vector in the game object. It then gets immutable values for x and y for the character of the team that is moving
    let x = vector::borrow(&game.teams, team).controllable_character.x;
    let y = vector::borrow(&game.teams, team).controllable_character.y;

    // Bounds checking to make sure the character doesn't overlap with the other character or a wall
    if (x == 0 || game.grid[y][x - 1] == WALL || game.grid[y][x - 1] == CHARACTER) {
        return // Return if the character is trying to move to an invalid location
    };

    // Get a mutable borrow from the teams vector in the game object. Do this to update the positioning of the character
    vector::borrow_mut(&mut game.teams, team).controllable_character.x = x - 1;
    vector::borrow_mut(&mut game.teams, team).controllable_character.y = y;

    // Change space to character space
    *&mut game.grid[y][x - 1] = CHARACTER;

    // Change space to normal tile
    *&mut game.grid[y][x] = TILE;
}

fun move_right(game: &mut Game, team: u64) {
    let x = vector::borrow(&game.teams, team).controllable_character.x;
    let y = vector::borrow(&game.teams, team).controllable_character.y;

    if (x == game.grid_size - 1 || game.grid[y][x + 1] == WALL || game.grid[y][x + 1] == CHARACTER) {
        return
    };

    vector::borrow_mut(&mut game.teams, team).controllable_character.x = x + 1;
    vector::borrow_mut(&mut game.teams, team).controllable_character.y = y;

    *&mut game.grid[y][x + 1] = CHARACTER; // Change space to character space
    *&mut game.grid[y][x] = TILE; // Change space to normal tile
}

fun move_up(game: &mut Game, team: u64) {
    let x = vector::borrow(&game.teams, team).controllable_character.x;
    let y = vector::borrow(&game.teams, team).controllable_character.y;

    if (y == 0 || game.grid[y - 1][x] == WALL || game.grid[y - 1][x] == CHARACTER) {
        return
    };

    vector::borrow_mut(&mut game.teams, team).controllable_character.x = x;
    vector::borrow_mut(&mut game.teams, team).controllable_character.y = y - 1;

    *&mut game.grid[y - 1][x] = CHARACTER; // Change space to character space
    *&mut game.grid[y][x] = TILE; // Change space to normal tile
}

fun move_down(game: &mut Game, team: u64) {
    let x = vector::borrow(&game.teams, team).controllable_character.x;
    let y = vector::borrow(&game.teams, team).controllable_character.y;

    if (y == game.grid_size - 1 || game.grid[y + 1][x] == WALL || game.grid[y + 1][x] == CHARACTER) {
        return
    };

    vector::borrow_mut(&mut game.teams, team).controllable_character.x = x;
    vector::borrow_mut(&mut game.teams, team).controllable_character.y = y + 1;

    *&mut game.grid[y + 1][x] = CHARACTER; // Change space to character space
    *&mut game.grid[y][x] = TILE; // Change space to normal tile
}
```

More on vectors in the [source code](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/move-stdlib/sources/vector.move).

Also remember that syntax such as `*&mut game.grid[y][x - 1] = CHARACTER;` means that we are indexing into a vector and changing the value at that location.

## Shooting Functions

The shooting functions are done in a similar fashion to the movement functions, so I will once again only explain the first function, but give you all of them.

```move
fun shoot_left(game: &mut Game, team: u64, ctx: &mut TxContext) {
    // Get x and y values from the character of the team that is shooting. Note that will x is mut, it is not changing the value of the actual object
    let mut x = vector::borrow(&game.teams, team).controllable_character.x;
    let y = vector::borrow(&game.teams, team).controllable_character.y;

    // Do a while loop and check each space in the path of the bullet until it runs into the other team's character or a wall
    while (x > 0) {
        x = x - 1;
        if(is_character(game, x, y)) {
            // If the bullet hits a character, replace with an X
            *&mut game.grid[y][x] = X;

            // The player has died, so call game_over
            game_over(game, team, ctx);
            return
        } else if (is_wall(game, x, y)) {
            // If it hits a wall, end the shot
            return
        };
    };
}

fun shoot_right(game: &mut Game, team: u64, ctx: &mut TxContext) {
    let mut x = vector::borrow(&game.teams, team).controllable_character.x;
    let y = vector::borrow(&game.teams, team).controllable_character.y;

    while (x < game.grid_size - 1) {
        x = x + 1;
        if(is_character(game, x, y)) {
            *&mut game.grid[y][x] = X;
            game_over(game, team, ctx);
            return
        } else if (is_wall(game, x, y)) {
            return
        };
    };
}

fun shoot_up(game: &mut Game, team: u64, ctx: &mut TxContext) {
    let x = vector::borrow(&game.teams, team).controllable_character.x;
    let mut y = vector::borrow(&game.teams, team).controllable_character.y;

    while (y > 0) {
        y = y - 1;
        if(is_character(game, x, y)) {
            *&mut game.grid[y][x] = X;
            game_over(game, team, ctx);
            return
        } else if (is_wall(game, x, y)) {
            return
        };
    };
}

fun shoot_down(game: &mut Game, team: u64, ctx: &mut TxContext) {
    let x = vector::borrow(&game.teams, team).controllable_character.x;
    let mut y = vector::borrow(&game.teams, team).controllable_character.y;

    while (y < game.grid_size - 1) {
        y = y + 1;
        if(is_character(game, x, y)) {
            *&mut game.grid[y][x] = X;
            game_over(game, team, ctx);
            return
        } else if (is_wall(game, x, y)) {
            return
        };
    };
}
```

## Conclusion

That's it for this part. There wasn't as much here compared to some of the other parts, but get ready for some serious game logic in the next part!
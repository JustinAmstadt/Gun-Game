# Gun Game: An Example in Sui On Chain Games Part 2

This is part 2 of the series, so check out part 1 if you are new.

In the last part we went over how to set up your environment. In this part we will make a project and build the foundational game state for our game. The ` a stepping stone to making the `Game` object

## Roadmap

Here is our roadmap that we are following:
- Setting up your environment
- Making the game state in Move *
- Making the game logic in Move
- Testing the game
- Writing Typescript code to interface with the blockchain

## The First Step: Making the Project

To start off this part of the tutorial, we will create the project we will do all of our contract coding in with this command:

```bash
sui move new gungame
```

Now, go into your new `gungame` folder and you will see the following layout:

```
gungame/
├── sources/
│   └── gungame.move
├── tests/
│   └── gungame_tests.move
└── Move.toml
```

Here is an explanation for each of the files:
- gungame.move: Where all of the game programming will go and is the heart of the contract.
- gungame_test.move: Where all of the testing of the game will go.
- Move.toml: Various information that you can add, but is mainly optional

This part will only be focusing on gungame.move file, but the next part will talk about testing.

## Your First Build

In gungame.move, change your file to look like the following:

```move
/// Module: gungame
module gungame::gungame {

}
```

From here, you can do your first compilation from inside the package with:

```bash
sui move build
```

Building periodically is a good way to check whether or not your code compile properly and I recommend you do so.

## Your First Address-Owned Object

As described in the first section, Sui objects are very easily made and assigned to addresses and they can allow you to do various things. They can be normal collectibles that don't do anything, but they can also be a way to give special permission to certain addresses.

How does it work? Here's an example:

Any function that is `public` can be called by any address, meaning that this function has no access control:

```move
public fun mint(&mut TxContext) {
    // This function mints to the person who called this function. Can be called by anyone.
}
```

Now, if you were to add an admin object that is minted in the same package as this mint function, only addresses that own an admin object from this package can call this function.

```move
public fun mint(_: &AdminCap, ctx: &mut TxContext) {
    // This function mints to to the person who called this function. Can only be called by addresses who have an AdminCap from this package.
}
```

`_: &AdminCap` means that it just needs the AdminCap, but it will not use it or change it.

It is also important to note that you can make as many admin objects as you want or forget to make any at all! They can also be any name and not just "AdminCap".

`TxContext` contains important information about the current transaction and only needs to be added when necessary. More information [here](https://github.com/sui-foundation/sui-move-intro-course/blob/main/unit-one/lessons/4_functions.md).

`ctx: &mut TxContext` means that you are using this variable in the function, passing it by reference, and mutating it

## Why is this Important Now?

Admin objects that allow access-controlled functions are critical for sensitive functions and are less prone to error that can lead to vulnerabilities.

The problem then becomes, how do you know which address can have an admin object in the first place? If it is a first-come first-serve system, you can see the potential issues.

That is why **the original publisher of the contract can be set to receive the admin object.** This is not automatic and comes in the form of an `init` function!

In our case, we will call the admin object a `GameMasterCap`, but any name will do.

```move
module gungame::game {
    // === Structs ===

    // You must define the object here!
    // As you can see, objects are just structs
    // "has key" means that it MUST have an id field and can be owned by addresses (very important!).
    public struct GameMasterCap has key {
        id: UID // A required field
    }

    // === Functions ===

    // Here is the init function
    fun init(ctx: &mut TxContext) {
        // Making a new object is just a matter of filling the struct out
        let gameMasterCap = GameMasterCap {
            id: object::new(ctx), // Syntax for making a UID
        };

        // Transfer the newly made gameMasterCap to the sender which in this case is the publisher of the contract
        transfer::transfer(gameMasterCap, ctx.sender());
    }
}
```

Put this new code in and try building it.

If you were to publish the contract and check the objects your address has, you will find a `GameMasterCap` assigned to your wallet. We will check this later.

## Make Teams

Since Gun Game is a team game, we must have a representation for both teams and the character each team will control.

Add these new objects to your `Structs` section. I will explain the `store` and `drop` abilites after:

```move
// === Structs ===
...
public struct ControllableCharacter has store, drop {
    x: u64, // Unsigned integer for x coordinate on board
    y: u64 // Unsigned integer for y coordinate on board
}

public struct Team has store, drop {
    move_queue: PriorityQueue<u64>, // Each team member can add moves to the queue that the character then uses in order. I couldn't find a normal queue implementation, so I just use a priority queue with all entries having a priority of 1
    controllable_character: ControllableCharacter // Both teams have a ControllableCharacter that is wrapped in this object
}
...
```

`store` means that other objects can contain this object.
`drop` means that an object can be ignored or discarded in a function.

More on abilities [here](https://move-book.com/move-basics/abilities-introduction.html).

You must also import the priority queue code with:

```move
module gungame::game {
    use sui::priority_queue::{Self, PriorityQueue, Entry};
    ...
}
```

You must now make the function that creates teams:

```move
// === Functions ===

...

// Takes a GameMasterCap, which then makes this function access-controlled. It also takes a grid size and returns a vector of Teams
fun make_teams(_: &GameMasterCap, grid_size: u64): vector<Team> {
    // Team vector initialization. Note the "mut" is similar to Rust and must be added if you want to add or remove anything from this vector
    let mut teams = vector::empty<Team>();
    
    // Add team 1 to the vector
    teams.push_back<Team>(Team {
        // The move queue initialization looks like a lot and it is, so feel free to just trust that it works. I left a link for more on this after this code
        move_queue: priority_queue::new<u64>(vector::empty<Entry<u64>>()),  
        // Initialize the team's character
        controllable_character: ControllableCharacter {
            x: 0, // Start out at 0, 0
            y: 0
        }
    });

    // Add team 2 to the vector. This is the same code, but with a different starting position
    teams.push_back<Team>(Team {
        move_queue: priority_queue::new<u64>(vector::empty<Entry<u64>>()),
        controllable_character: ControllableCharacter {
            x: grid_size - 1,
            y: grid_size - 1 
        }
    });

    teams // Return the team vector
}

...
```

The interested can learn more about priority queues [here](https://docs.sui.io/references/framework/sui-framework/priority_queue#function-new).

## Make the Game Grid

Everything is represented with objects including the game state itself. Before we get into creating a complete game state object, we must first make the grid that the game will use.

We will now learn about the `Random` object here!

Import the random module:

```move
module gungame::game {
    ...
    use sui::random::{Self, Random};
    ...
}
```

More details on the `Random` class [here](https://docs.sui.io/guides/developer/advanced/randomness-onchain).

Add a new section for constants below the imports and above the structs:

```move
// === Constants ===

// Proper ascii values of tiles we are using to make the code more readable
const CHARACTER: u8 = 38;
const TILE: u8 = 42;
const WALL: u8 = 35;
```

```move
// === Functions ===

...

// This grid will contain the ascii representations of characters that can then be interpreted when we read the data in at the Typescript level
fun make_grid (
    grid_size: u64, 
    char1_x: u64, // X location of the character for team 1
    char1_y: u64, // Y location of the character for team 1
    char2_x: u64, // X location of the character for team 2
    char2_y: u64, // Y location of the character for team 2
    r: &Random, // The Random object! r: &Random means that you will use the variable, but not change it
    ctx: &mut TxContext // The transaction context
): vector<vector<u8>> { // Returns a 2D vector of unsigned 8 bit integers. We use u8 to save gas since we don't need any bigger
    // Required to generate random numbers
    let mut generator = random::new_generator(r, ctx);

    // Required for the upcoming while loops. Note how they are "mut"
    let mut i = 0;
    let mut j = 0;

    // Initialize an empty grid to contain ascii values
    let mut grid = vector::empty<vector<u8>>();

    // Make a row variable
    let mut row: vector<u8>;

    // To my knowledge, for loops don't exist, so we are stuck with while loops
    while (i < grid_size) {
        // Give the row an empty vector
        row = vector::empty<u8>();

        // Make each row a set of normal tiles
        while (j < grid_size) {
            // Generate normal tiles
            row.push_back<u8>(TILE);
            j = j + 1;
        };

        if (i != 0 && i != grid_size - 1) {
            // Generate walls randomly with one wall per row with a restriction that there cannot be a wall on the last set of tiles at the edges
            *&mut row[random::generate_u64_in_range(&mut generator, 1, grid_size - 2)] = WALL;
        };

        // Add the row to the grid
        grid.push_back<vector<u8>>(row);
        i = i + 1;
        j = 0;
    };

    // Generate players
    *&mut grid[char1_y][char1_x] = CHARACTER;
    *&mut grid[char2_y][char2_x] = CHARACTER;

    grid // Return the grid
}

...
```

You may be wondering what `*&mut` means. It looks gross and hard to understand, but it is required whenever you are indexing a vector and changing the value there. 

The other crazy thing is it is *very easy* to use randomness in Sui with a couple of security considerations. More on that later.

## Make the Game Object

We have finally set the groundwork to make our `Game` object which will contain all information pertaining to the game state.

We have a new module to add:

```move
module gungame::game {
    ...
    use std::string;
    use sui::vec_map::{Self, VecMap};
    ...
}
```

A `VecMap` can be thought of as a hash map or a dictionary. More details [here](https://move-book.com/programmability/collections.html). I have also found [the source code itself](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/vec_map.move) to be very useful.

We will now need to add a `Player` object and a `Game` object.

The `Player` object will be used as a record for a player that contains the address of that player, the name the player chose, and the team the player was assigned to.

The `Game` object contains game state information.

Here they are:

```move
public struct Game has key, store {
    id: UID,
    players: VecMap<address, Player>, // A map to connect an address that calls a function to a player
    teams: vector<Team>, // A vector of teams
    team1_player_count: u64, // Number of players on team 1
    team2_player_count: u64, // Number of players on team 2

    grid: vector<vector<u8>>, // The grid
    grid_size: u64, // The grid size
    reset_grid: bool // Whether or not to reset the grid
}

public struct Player has store, drop {
    name: string::String, // A name that the player gives
    address: address, // The address of this player
    team: u64 // The team this player was assigned to
}
```

Here is the function to now make a `Game` object:

```move
// This suppresses a warning for adding accepting a random object to a public function. There is no risk here since this function is access controlled by the GameMasterCap
#[allow(lint(public_random))]
public fun make_game(gameMasterCap: &GameMasterCap, grid_size: u64, r: &Random, ctx: &mut TxContext) {
    // Make the teams
    let teams = make_teams(gameMasterCap, grid_size);
    // Make the grid
    let grid = make_grid(grid_size, 0, 0, grid_size - 1, grid_size - 1, r, ctx);

    // Make the game object
    let game = Game {
        id: object::new(ctx), // Give it an id
        players: vec_map::empty<address, Player>(), // Initialize an empty VecMap
        teams: teams, // Give the teams
        team1_player_count: 0, // Initialize player counts
        team2_player_count: 0,
        grid: grid, // Give the grid
        grid_size: grid_size, // Give the grid_size
        reset_grid: false // Don't reset the grid
    };

    // Make the game a shared object so that everyone can access it
    transfer::share_object(game);
}
```

More on shared objects [here](https://move-book.com/object/ownership.html).

## Conclusion

We have completed our game state creation and we are now ready to add some real logic to the game in the next part.
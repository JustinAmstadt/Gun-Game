/// Module: gungame
module gungame::gungame {
    use std::string;
    use sui::priority_queue::{Self, PriorityQueue, Entry};
    use sui::random::{Self, Random};
    use sui::vec_map::{Self, VecMap};
    use sui::event;

    // === Constants ===

    // Proper ascii values of tiles we are using to make the code more readable
    const CHARACTER: u8 = 38;
    const TILE: u8 = 42;
    const WALL: u8 = 35;
    const X: u8 = 88;

    const TEAM_1: u64 = 0;
    const TEAM_2: u64 = 1;

    // === Structs ===

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

    // You must define the object here!
    // As you can see, objects are just structs
    // "has key" means that it MUST have an id field and can be owned by addresses (very important!).
    public struct GameMasterCap has key {
        id: UID // A required field
    }

    public struct ControllableCharacter has store, drop {
        x: u64, // Unsigned integer for x coordinate on board
        y: u64 // Unsigned integer for y coordinate on board
    }

    public struct Team has store, drop {
        move_queue: PriorityQueue<u64>, // Each team member can add moves to the queue that the character then uses in order. I couldn't find a normal queue implementation, so I just use a priority queue with all entries having a priority of 1
        controllable_character: ControllableCharacter // Both teams have a ControllableCharacter that is wrapped in this object
    }

    public struct Player has store, drop {
        name: string::String, // A name that the player gives
        address: address, // The address of this player
        team: u64 // The team this player was assigned to
    }

    // === Events ===

    public struct PlayerJoined has copy, drop {
        playerName: string::String, // Player name that the player chooses
        playerAddress: address, // Address that the player is using to make transactions
        team: u64 // The team the player was assigned to
    }

    // This is the same data as PlayerJoined
    public struct PlayerLeft has copy, drop {
        playerName: string::String,
        playerAddress: address,
        team: u64
    }

    public struct PlayerKicked has copy, drop {
        playerName: string::String,
        playerAddress: address,
        team: u64
    }

    // === Errors ===

    const EPlayerNotInGame: u64 = 0;
    const EPlayerAlreadyInGame: u64 = 1;

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

    fun game_over(game: &mut Game, winning_team: u64, ctx: &mut TxContext) {
    }

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

    fun is_wall(game: &Game, x: u64, y: u64): bool {
        game.grid[y][x] == WALL
    }

    fun is_character(game: &Game, x: u64, y: u64): bool {
        game.grid[y][x] == CHARACTER
    }
}
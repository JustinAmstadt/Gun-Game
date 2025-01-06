/// Module: gungame
module gungame::gungame {
    use std::string;
    use sui::priority_queue::{Self, PriorityQueue, Entry};
    use sui::random::{Self, Random};
    use sui::vec_map::{Self, VecMap};
    use sui::event;
    use std::debug;

    // === Constants ===

    // Proper ascii values of tiles we are using to make the code more readable
    const CHARACTER: u8 = 38;
    const TILE: u8 = 42;
    const WALL: u8 = 35;
    const X: u8 = 88;

    const TEAM_1: u64 = 0;
    const TEAM_2: u64 = 1;

    const MOVE_LEFT: u64 = 0;
    const MOVE_RIGHT: u64 = 1;
    const MOVE_UP: u64 = 2;
    const MOVE_DOWN: u64 = 3;

    const SHOOT_LEFT: u64 = 4;
    const SHOOT_RIGHT: u64 = 5;
    const SHOOT_UP: u64 = 6;
    const SHOOT_DOWN: u64 = 7;

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

    public struct GamePlayed has copy, drop {
        playerName: string::String,
        playerAddress: address,
        player_choice: u64
    }

    // This is the actual NFT to be minted
    public struct GameResult has key, store {
        id: UID,
        name: string::String,
        message: string::String
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

    public struct GameOutcomeMinted has copy, drop {
        objectAddress: address,
        playerName: string::String,
        playerAddress: address
    }

    // === Errors ===

    const EPlayerNotInGame: u64 = 0;
    const EPlayerAlreadyInGame: u64 = 1;
    const EInvalidInput: u64 = 2;
    const ETeamDoesNotExist : u64 = 3;

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
    
    fun is_queue_empty(game: &Game, team: u64): bool {
        game.teams[team].move_queue.priorities().is_empty()
    }

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

    // game: Must be &mut because player_action requires it to be
    // player_choice: The integer that will be inserted into the move queue
    // r: The Random variable that will be used if the game needs to reset
    // ctx: The transaction context
    entry fun play_game(game: &mut Game, player_choice: u64, r: &Random, _ctx: &mut TxContext) {
        // An assert to make sure the player is in the game
        assert!(vec_map::contains(&game.players, &_ctx.sender()), EPlayerNotInGame);

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
            game.grid = make_grid(game.grid_size, 0, 0, game.grid_size - 1, game.grid_size - 1, r, _ctx);

            // Reset character positionings
            vector::borrow_mut(&mut game.teams, TEAM_1).controllable_character.x = 0;
            vector::borrow_mut(&mut game.teams, TEAM_1).controllable_character.y = 0;
            vector::borrow_mut(&mut game.teams, TEAM_2).controllable_character.x = game.grid_size - 1;
            vector::borrow_mut(&mut game.teams, TEAM_2).controllable_character.y = game.grid_size - 1;
        };

        // Look up the player in the VecMap to see which team they are on. "team" is an integer that will be used to index into the game.teams field
        let team = vec_map::get(&game.players, &_ctx.sender()).team;

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
            playerName: game.players.get(&_ctx.sender()).name,
            playerAddress: _ctx.sender(),
            player_choice: player_choice
        };

        // Emit the event
        event::emit(event);

        // This logic determines who goes first based on whether or not a team is shooting or not. Always let the team that is moving go first if the other is shooting. If both teams are shooting then the move cancels and nothing happens
        if (is_team_shoot && !is_enemy_team_shoot) {
            player_action(game, enemy_team, next_move_enemy_team, _ctx);
            player_action(game, team, next_move_team, _ctx);
        } else if (is_enemy_team_shoot && !is_team_shoot) {
            player_action(game, team, next_move_team, _ctx);
            player_action(game, enemy_team, next_move_enemy_team,  _ctx);
        } else if (!is_team_shoot && !is_enemy_team_shoot) {
            player_action(game, team, next_move_team, _ctx);
            player_action(game, enemy_team, next_move_enemy_team, _ctx);
        }
    }

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

    fun game_over(game: &mut Game, winning_team: u64, ctx: &mut TxContext) {
        mint_game_result(game, winning_team, ctx);
        game.reset_grid = true; // Used in the play_game function to check if the game needs to be reset
        empty_queues(game);
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

    #[allow(unused_function)]
    fun is_x(game: &Game, x: u64, y: u64): bool {
        game.grid[y][x] == X
    }

    #[allow(unused_function)]
    fun is_tile(game: &Game, x: u64, y: u64): bool {
        game.grid[y][x] == TILE
    }

    #[test_only]
    public fun teleport_player(game: &mut Game, team: u64, x: u64, y: u64) {
        let prevX = vector::borrow(&game.teams, team).controllable_character.x;
        let prevY = vector::borrow(&game.teams, team).controllable_character.y;

        vector::borrow_mut(&mut game.teams, team).controllable_character.x = x;
        vector::borrow_mut(&mut game.teams, team).controllable_character.y = y;

        if (!(prevX == x && prevY == y)) { // Don't replace with a tile if a character is already there
            *&mut game.grid[y][x] = CHARACTER; // Change space to character space
            *&mut game.grid[prevY][prevX] = TILE; // Change space to normal tile
        }
    }

    #[test_only]
    public fun print_grid(game: &mut Game) {
        debug::print(&game.grid);
    }

    #[test_only]
    public fun get_character_coords(game: &mut Game, team: u64): (u64, u64) {
        let x = vector::borrow(&game.teams, team).controllable_character.x;
        let y = vector::borrow(&game.teams, team).controllable_character.y;

        (x, y)
    }

    #[test_only]
    public fun public_is_wall(game: &mut Game, x: u64, y: u64): bool {
        is_wall(game, x, y)
    }

    #[test_only]
    public fun test_is_tile(game: &mut Game, x: u64, y: u64): bool {
        is_tile(game, x, y)
    }

    #[test_only]
    public fun test_is_x(game: &mut Game, x: u64, y: u64): bool {
        is_x(game, x, y)
    }

    #[test_only]
    // This is only used a specific test case!! Use teleport_player unless you are careful with updating variables
    public fun test_is_character(game: &mut Game, x: u64, y: u64): bool {
        is_character(game, x, y)
    }

    #[test_only]
    public fun place_wall(game: &mut Game, x: u64, y: u64) {
        *&mut game.grid[y][x] = WALL;
    }

    #[test_only]
    public fun place_tile(game: &mut Game, x: u64, y: u64) {
        *&mut game.grid[y][x] = TILE;
    }

    #[test_only]
    public fun place_character(game: &mut Game, x: u64, y: u64) {
        *&mut game.grid[y][x] = CHARACTER;
    }

    #[test_only]
    public fun make_all_tiles(game: &mut Game) {
        let mut y = 0;
        let mut x = 0;

        while (y < game.grid_size) {
            while (x < game.grid_size) {
                *&mut game.grid[y][x] = TILE;
                x = x + 1;
            };
            y = y + 1;
            x = 0
        };
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun get_team(game: &Game, player: address): u64 {
        vec_map::get(&game.players, &player).team
    }

    #[test_only]
    public fun get_team_player_count(game: &Game): (u64, u64) {
        let team1 = game.team1_player_count;
        let team2 = game.team2_player_count;

        (team1, team2)
    }

    #[test_only]
    public fun test_mint_game_result(game: &mut Game, winningTeam: u64, ctx: &mut TxContext) {
        mint_game_result(game, winningTeam, ctx);
    }

    #[test_only]
    public fun test_player_action(game: &mut Game, team: u64, player_choice: u64, ctx: &mut TxContext) {
        player_action(game, team, player_choice, ctx);
    }
}
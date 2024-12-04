module gungame::game {
    use std::string;
    use sui::random::{Self, Random};
    use sui::vec_map::{Self, VecMap};
    use sui::priority_queue::{Self, PriorityQueue, Entry};
    use sui::event;
    use std::debug;

    // === Constants ===

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
        players: VecMap<address, Player>,
        teams: vector<Team>,
        team1_player_count: u64,
        team2_player_count: u64,

        grid: vector<vector<u8>>,
        grid_size: u64,
        reset_grid: bool
    }

    public struct ControllableCharacter has store, drop {
        x: u64,
        y: u64
    }

    public struct Team has store, drop {
        move_queue: PriorityQueue<u64>,
        controllable_character: ControllableCharacter
    }

    public struct Player has store, drop {
        name: string::String,
        address: address,
        team: u64
    }

    public struct GameResult has key, store {
        id: UID,
        name: string::String,
        message: string::String
    }

    public struct GameMasterCap has key {
        id: UID
    }

    // === Events ===

    public struct GamePlayed has copy, drop {
        playerName: string::String,
        playerAddress: address,
        player_choice: u64
    }

    public struct GameOutcomeMinted has copy, drop {
        objectAddress: address,
        playerName: string::String,
        playerAddress: address
    }

    public struct PlayerJoined has copy, drop {
        playerName: string::String,
        playerAddress: address,
        team: u64
    }

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
    const EInvalidInput: u64 = 2;
    const ETeamDoesNotExist : u64 = 3;

    // === Functions ===

    fun init(ctx: &mut TxContext) {
        let gameMasterCap = GameMasterCap {
            id: object::new(ctx),
        };

        transfer::transfer(gameMasterCap, ctx.sender());
    }

    fun make_teams(_: &GameMasterCap, grid_size: u64): vector<Team> {
        let mut teams = vector::empty<Team>();
        
        // team 1
        teams.push_back<Team>(Team {
            move_queue: priority_queue::new<u64>(vector::empty<Entry<u64>>()),
            controllable_character: ControllableCharacter {
                x: 0,
                y: 0
            }
        });

        // team 2
        teams.push_back<Team>(Team {
            move_queue: priority_queue::new<u64>(vector::empty<Entry<u64>>()),
            controllable_character: ControllableCharacter {
                x: grid_size - 1,
                y: grid_size - 1 
            }
        });

        teams
    }

    fun make_grid (
        grid_size: u64, 
        char1_x: u64, 
        char1_y: u64,
        char2_x: u64, 
        char2_y: u64,
        r: &Random, 
        ctx: &mut TxContext
    ): vector<vector<u8>> {
        let mut generator = random::new_generator(r, ctx);

        let mut i = 0;
        let mut j = 0;
        let mut grid = vector::empty<vector<u8>>();
        let mut row: vector<u8>;

        while (i < grid_size) {
            row = vector::empty<u8>();

            while (j < grid_size) {
                // Generate normal tiles
                row.push_back<u8>(TILE); // 42 is the value for *
                j = j + 1;
            };

            if (i != 0 && i != grid_size - 1) {
                // Generate walls
                *&mut row[random::generate_u64_in_range(&mut generator, 1, grid_size - 2)] = WALL; // 35 is the value for #
            };

            grid.push_back<vector<u8>>(row);
            i = i + 1;
            j = 0;
        };

        // Generate players
        *&mut grid[char1_y][char1_x] = 38; // 38 is the value for &
        *&mut grid[char2_y][char2_x] = 38;

        grid
    }

    #[allow(lint(public_random))]
    public fun make_game(gameMasterCap: &GameMasterCap, grid_size: u64, r: &Random, ctx: &mut TxContext) {
        let teams = make_teams(gameMasterCap, grid_size);
        let grid = make_grid(grid_size, 0, 0, grid_size - 1, grid_size - 1, r, ctx);

        let game = Game {
            id: object::new(ctx),
            players: vec_map::empty<address, Player>(),
            teams: teams,
            team1_player_count: 0,
            team2_player_count: 0,
            grid: grid,
            grid_size: grid_size,
            reset_grid: false
        };

        transfer::share_object(game);
    }

    fun mint_game_result(game: &mut Game, winning_team: u64, ctx: &mut TxContext) {
        assert!(winning_team == TEAM_1 || winning_team == TEAM_2, ETeamDoesNotExist);

        while (!game.players.is_empty()) {
            let (_key, player) = game.players.pop();

            if (player.team != winning_team) {
                continue
            };

            let gameResult = GameResult {
                id: object::new(ctx),
                name: player.name,
                message: string::utf8(b"You won the game!")
            };

            let event = GameOutcomeMinted {
                objectAddress: object::id_to_address(&object::id(&gameResult)),
                playerAddress: player.address,
                playerName: player.name
            };

            event::emit(event);
            transfer::public_transfer(gameResult, player.address);
        }
    }

    public fun join_game(game: &mut Game, name: string::String, ctx: &mut TxContext) {
        assert!(!vec_map::contains(&game.players, &ctx.sender()), EPlayerAlreadyInGame);

        let player: Player;
        if (game.team1_player_count > game.team2_player_count) {
            player = Player {
                name: name,
                address: ctx.sender(),
                team: TEAM_2
            };

            game.team2_player_count = game.team2_player_count + 1;
        } else {
            player = Player {
                name: name,
                address: ctx.sender(),
                team: TEAM_1
            };

            game.team1_player_count = game.team1_player_count + 1;
        };

        let event = PlayerJoined {
            playerName: name,
            playerAddress: ctx.sender(),
            team: player.team
        };

        event::emit(event);
        game.players.insert(ctx.sender(), player);
    }

    public fun leave_game(game: &mut Game, ctx: &mut TxContext) {
        assert!(vec_map::contains(&game.players, &ctx.sender()), EPlayerNotInGame);

        let (_key, player) = vec_map::remove(&mut game.players, &ctx.sender());

        if (player.team == TEAM_1) {
            game.team1_player_count = game.team1_player_count - 1;
        } else {
            game.team2_player_count = game.team2_player_count - 1;
        };

        let event = PlayerLeft {
            playerName: player.name,
            playerAddress: ctx.sender(),
            team: player.team
        };

        event::emit(event);
    }

    public fun kick_player(_: &GameMasterCap, game: &mut Game, playerAddress: address) {
        assert!(vec_map::contains(&game.players, &playerAddress), EPlayerNotInGame);

        let (_key, player) = vec_map::remove(&mut game.players, &playerAddress);

        if (player.team == TEAM_1) {
            game.team1_player_count = game.team1_player_count - 1;
        } else {
            game.team2_player_count = game.team2_player_count - 1;
        };

        let event = PlayerKicked {
            playerName: player.name,
            playerAddress: playerAddress,
            team: player.team
        };

        event::emit(event);
    }

    fun is_queue_empty(game: &Game, team: u64): bool {
        game.teams[team].move_queue.priorities().is_empty()
    }

    fun empty_queues(game: &mut Game) {
        while (!is_queue_empty(game, TEAM_1)) {
            game.teams[TEAM_1].move_queue.pop_max<u64>();
        };
        while (!is_queue_empty(game, TEAM_2)) {
            game.teams[TEAM_2].move_queue.pop_max<u64>();
        };
    }

    entry fun play_game(game: &mut Game, player_choice: u64, r: &Random, _ctx: &mut TxContext) {
        assert!(vec_map::contains(&game.players, &_ctx.sender()), EPlayerNotInGame);

        if (game.reset_grid) {
            game.reset_grid = false;
            game.grid = make_grid(game.grid_size, 0, 0, game.grid_size - 1, game.grid_size - 1, r, _ctx);
            vector::borrow_mut(&mut game.teams, TEAM_1).controllable_character.x = 0;
            vector::borrow_mut(&mut game.teams, TEAM_1).controllable_character.y = 0;
            vector::borrow_mut(&mut game.teams, TEAM_2).controllable_character.x = game.grid_size - 1;
            vector::borrow_mut(&mut game.teams, TEAM_2).controllable_character.y = game.grid_size - 1;
        };

        let team = vec_map::get(&game.players, &_ctx.sender()).team;
        let mut enemy_team = 0;

        if (team == 0) {
            enemy_team = 1;
        };

        game.teams[team].move_queue.insert<u64>(1, player_choice);

        if (is_queue_empty(game, enemy_team)) {
            return
        };

        let (_priority_team, next_move_team) = game.teams[team].move_queue.pop_max<u64>();
        let (_priority_enemy_team, next_move_enemy_team) = game.teams[enemy_team].move_queue.pop_max<u64>();

        let is_team_shoot = next_move_team > 3;
        let is_enemy_team_shoot = next_move_enemy_team > 3;

        let event = GamePlayed {
            playerName: game.players.get(&_ctx.sender()).name,
            playerAddress: _ctx.sender(),
            player_choice: player_choice
        };

        event::emit(event);

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
        } else {
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
        };
    }

    fun game_over(game: &mut Game, winning_team: u64, ctx: &mut TxContext) {
        mint_game_result(game, winning_team, ctx);
        game.reset_grid = true;
        empty_queues(game);
    }

    fun move_left(game: &mut Game, team: u64) {
        let x = vector::borrow(&game.teams, team).controllable_character.x;
        let y = vector::borrow(&game.teams, team).controllable_character.y;

        if (x == 0 || game.grid[y][x - 1] == WALL || game.grid[y][x - 1] == CHARACTER) {
            return
        };

        vector::borrow_mut(&mut game.teams, team).controllable_character.x = x - 1;
        vector::borrow_mut(&mut game.teams, team).controllable_character.y = y;

        *&mut game.grid[y][x - 1] = CHARACTER; // Change space to character space
        *&mut game.grid[y][x] = TILE; // Change space to normal tile
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
        let mut x = vector::borrow(&game.teams, team).controllable_character.x;
        let y = vector::borrow(&game.teams, team).controllable_character.y;

        while (x > 0) {
            x = x - 1;
            if(is_character(game, x, y)) {
                *&mut game.grid[y][x] = X;
                game_over(game, team, ctx);
                return
            } else if (is_wall(game, x, y)) {
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

    #[allow(unused_function)]
    fun is_tile(game: &Game, x: u64, y: u64): bool {
        game.grid[y][x] == TILE
    }

    fun is_character(game: &Game, x: u64, y: u64): bool {
        game.grid[y][x] == CHARACTER
    }

    #[allow(unused_function)]
    fun is_x(game: &Game, x: u64, y: u64): bool {
        game.grid[y][x] == X
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
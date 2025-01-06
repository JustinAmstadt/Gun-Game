#[test_only]
#[allow(unused_const)]
module gungame::gungame_tests{
    use sui::test_scenario;
    use gungame::game::{Self, GameMasterCap, Game, GameResult};
    use sui::random::{Self, Random};
    use std::string;

    const EPlayerInWrongTeam: u64 = 1;
    const EWrongPlayerCount: u64 = 2;
    const EIncorrectPlayerMovement: u64 = 3;
    const EIncorrectTilePlacement: u64 = 4;
    const EIncorrectCharacterCoordinates: u64 = 6;
    const EPlayerNotShot: u64 = 7;

    const MOVE_LEFT: u64 = 0;
    const MOVE_RIGHT: u64 = 1;
    const MOVE_UP: u64 = 2;
    const MOVE_DOWN: u64 = 3;

    const SHOOT_LEFT: u64 = 4;
    const SHOOT_RIGHT: u64 = 5;
    const SHOOT_UP: u64 = 6;
    const SHOOT_DOWN: u64 = 7;

    #[test]
    fun test_play_game() {
        let admin = @0xAD;
        let player1 = @0x01;
        let player2 = @0x02;

        let team_1 = 0;
        let team_2 = 1;

        let playerName = string::utf8(b"PlayerName");

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, 7, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::make_all_tiles(&mut game);
            game::teleport_player(&mut game, team_1, 3, 0);
            game::teleport_player(&mut game, team_2, 3, 2);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, MOVE_RIGHT, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, MOVE_RIGHT, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, SHOOT_DOWN, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, MOVE_DOWN, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        // We know it all went through if the players got removed from the players VecMap
        // If they weren't removed, the next to txs should fail
        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        // Test to make sure a move happens before a shot
        // If the player gets shot and dies, the next tx after will fail because the players get removed
        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, SHOOT_DOWN, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::make_all_tiles(&mut game);
            game::teleport_player(&mut game, team_1, 3, 0);
            game::teleport_player(&mut game, team_2, 3, 2);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, MOVE_RIGHT, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, MOVE_RIGHT, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, SHOOT_UP, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        // Player 1 should die, so they should both be able to join again
        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::end(scenario_val); // End the scenario and give back scenario_val
    }

    #[test]
    fun test_game_creation() {
        let admin = @0xAD;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, 7, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_join_leave_game() {
        let admin = @0xAD;
        let player1 = @0x01;
        let player2 = @0x02;
        let player3 = @0x03;

        let playerName = string::utf8(b"PlayerName");

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, 7, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player3);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);

            assert!(game::get_team(&game, player1) == 0, EPlayerInWrongTeam);
            assert!(game::get_team(&game, player2) == 1, EPlayerInWrongTeam);
            assert!(game::get_team(&game, player3) == 0, EPlayerInWrongTeam);
            
            let (team1, team2) = game::get_team_player_count(&game);
            assert!(team1 == 2, EWrongPlayerCount);
            assert!(team2 == 1, EWrongPlayerCount);

            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::leave_game(&mut game, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);
            let (team1, _team2) = game::get_team_player_count(&game);
            assert!(team1 == 1, EWrongPlayerCount);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::end(scenario_val); // End the scenario and give back scenario_val
    }

    #[test]
    fun test_kick_player() {
        let admin = @0xAD;
        let player1 = @0x01;

        let playerName = string::utf8(b"PlayerName");

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, 7, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::kick_player(&gmCap, &mut game, player1);
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let game = test_scenario::take_shared<Game>(scenario);
            let (team1, _team2) = game::get_team_player_count(&game);
            assert!(team1 == 0, EWrongPlayerCount);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::end(scenario_val); // End the scenario and give back scenario_val
    }

    #[test]
    fun test_mint_game_result() {
        let admin = @0xAD;
        let player1 = @0x01;
        let player2 = @0x02;
        let player3 = @0x03;

        let playerName = string::utf8(b"PlayerName");

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, 7, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player3);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::test_mint_game_result(&mut game, 0, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let gameResult = scenario.take_from_sender<GameResult>();
            scenario.return_to_sender(gameResult);
        };

        test_scenario::next_tx(scenario, player3);
        {
            let gameResult = scenario.take_from_sender<GameResult>();
            scenario.return_to_sender(gameResult);
        };

        test_scenario::end(scenario_val); // End the scenario and give back scenario_val
    }

    #[test]
    fun test_player_shoot() {
        let admin = @0xAD;
        let player1 = @0x01;
        let player2 = @0x02;

        let grid_size = 7;
        let team_1 = 0;
        let team_2 = 1;

        let team_1_x = 3;
        let team_1_y = 3;

        let shoot_left = 4;
        let shoot_right = 5;
        let shoot_up = 6;
        let shoot_down = 7;

        let playerName = string::utf8(b"PlayerName");

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, grid_size, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        // Turn everything into a tiles then replace the characters in the top corners
        test_scenario::next_tx(scenario, admin);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);

            game::make_all_tiles(&mut game);

            // Move team 1 character
            game::teleport_player(&mut game, team_1, team_1_x, team_1_y);

            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);

            // Move team 2 character to the left of character 1
            game::teleport_player(&mut game, team_2, 0, team_1_y);
            game::test_player_action(&mut game, team_1, shoot_left, scenario.ctx());
            assert!(game::test_is_x(&mut game, 0, team_1_y), EPlayerNotShot);

            // Move chararacter 2 to the right
            game::teleport_player(&mut game, team_2, 6, team_1_y);
            game::test_player_action(&mut game, team_1, shoot_right, scenario.ctx());
            assert!(game::test_is_x(&mut game, grid_size - 1, team_1_y), EPlayerNotShot);

            // Move chararacter 2 to the top
            game::teleport_player(&mut game, team_2, team_1_x, 0);
            game::test_player_action(&mut game, team_1, shoot_up, scenario.ctx());
            assert!(game::test_is_x(&mut game, team_1_x, 0), EPlayerNotShot);

            // Move chararacter 2 to the bottom
            game::teleport_player(&mut game, team_2, team_1_x, grid_size - 1);
            game::test_player_action(&mut game, team_1, shoot_down, scenario.ctx());
            assert!(game::test_is_x(&mut game, team_1_x, grid_size - 1), EPlayerNotShot);

            // Add walls around character 1
            game::place_wall(&mut game, team_1_x - 1, team_1_y);
            game::place_wall(&mut game, team_1_x + 1, team_1_y);
            game::place_wall(&mut game, team_1_x, team_1_y + 1);
            game::place_wall(&mut game, team_1_x, team_1_y - 1);

            // Move team 2 character to the left of character 1
            game::teleport_player(&mut game, team_2, 0, team_1_y);
            game::test_player_action(&mut game, team_1, shoot_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, 0, team_1_y), EPlayerNotShot);

            // Move chararacter 2 to the right
            game::teleport_player(&mut game, team_2, 6, team_1_y);
            game::test_player_action(&mut game, team_1, shoot_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, grid_size - 1, team_1_y), EPlayerNotShot);

            // Move chararacter 2 to the top
            game::teleport_player(&mut game, team_2, team_1_x, 0);
            game::test_player_action(&mut game, team_1, shoot_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, team_1_x, 0), EPlayerNotShot);

            // Move chararacter 2 to the bottom
            game::teleport_player(&mut game, team_2, team_1_x, grid_size - 1);
            game::test_player_action(&mut game, team_1, shoot_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, team_1_x, grid_size - 1), EPlayerNotShot);

            // Reset grid to just character 1 in middle
            game::make_all_tiles(&mut game);
            game::teleport_player(&mut game, team_1, team_1_x, team_1_y);

            // Test shoot grid boundaries
            game::test_player_action(&mut game, team_1, shoot_left, scenario.ctx());
            game::test_player_action(&mut game, team_1, shoot_right, scenario.ctx());
            game::test_player_action(&mut game, team_1, shoot_up, scenario.ctx());
            game::test_player_action(&mut game, team_1, shoot_down, scenario.ctx());

            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::end(scenario_val); // End the scenario and give back scenario_val
    }
    
    #[test]
    fun test_player_movement() {
        let admin = @0xAD;
        let player1 = @0x01;
        let player2 = @0x02;

        let playerName = string::utf8(b"PlayerName");
        
        let grid_size = 7;

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, grid_size, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        // Test Movement for character 1
        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);

            let team = 0;
            let mut startX = 3;
            let mut startY = 2;

            let move_left = 0;
            let move_right = 1;
            let move_up = 2;
            let move_down = 3;
            
            // Move player's position
            game::teleport_player(&mut game, team, startX, startY);

            // Ensure no walls around player
            game::place_tile(&mut game, startX - 1, startY);
            game::place_tile(&mut game, startX + 1, startY);
            game::place_tile(&mut game, startX, startY + 1);
            game::place_tile(&mut game, startX, startY - 1);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX - 1, startY), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX, startY), EIncorrectTilePlacement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX - 1, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX - 1, startY), EIncorrectTilePlacement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY - 1), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX, startY), EIncorrectTilePlacement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY - 1, EIncorrectCharacterCoordinates);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX, startY - 1), EIncorrectTilePlacement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Add walls around player
            game::place_wall(&mut game, startX - 1, startY);
            game::place_wall(&mut game, startX + 1, startY);
            game::place_wall(&mut game, startX, startY + 1);
            game::place_wall(&mut game, startX, startY - 1);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Add players around player
            game::place_character(&mut game, startX - 1, startY);
            game::place_character(&mut game, startX + 1, startY);
            game::place_character(&mut game, startX, startY + 1);
            game::place_character(&mut game, startX, startY - 1);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test out of bounds

            startX = 0;
            startY = 0;

            // Teleport character to top left edge
            game::teleport_player(&mut game, team, startX, startY);
            
            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            startX = grid_size - 1;
            startY = grid_size - 1;

            // Teleport character to top left edge
            game::teleport_player(&mut game, team, startX, startY);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        // Test Movement for character 2
        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);

            let team = 1;
            let mut startX = 3;
            let mut startY = 4;

            let move_left = 0;
            let move_right = 1;
            let move_up = 2;
            let move_down = 3;
            
            // Move player's position
            game::teleport_player(&mut game, team, startX, startY);

            // Ensure no walls around player
            game::place_tile(&mut game, startX - 1, startY);
            game::place_tile(&mut game, startX + 1, startY);
            game::place_tile(&mut game, startX, startY + 1);
            game::place_tile(&mut game, startX, startY - 1);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX - 1, startY), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX, startY), EIncorrectTilePlacement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX - 1, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX - 1, startY), EIncorrectTilePlacement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY - 1), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX, startY), EIncorrectTilePlacement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY - 1, EIncorrectCharacterCoordinates);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            assert!(game::test_is_tile(&mut game, startX, startY - 1), EIncorrectTilePlacement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Add walls around player
            game::place_wall(&mut game, startX - 1, startY);
            game::place_wall(&mut game, startX + 1, startY);
            game::place_wall(&mut game, startX, startY + 1);
            game::place_wall(&mut game, startX, startY - 1);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Add players around player
            game::place_character(&mut game, startX - 1, startY);
            game::place_character(&mut game, startX + 1, startY);
            game::place_character(&mut game, startX, startY + 1);
            game::place_character(&mut game, startX, startY - 1);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test out of bounds

            startX = 0;
            startY = 0;

            // Teleport character to top left edge
            game::teleport_player(&mut game, team, startX, startY);
            
            // Test move up
            game::test_player_action(&mut game, team, move_up, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move left
            game::test_player_action(&mut game, team, move_left, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            startX = grid_size - 1;
            startY = grid_size - 1;

            // Teleport character to top left edge
            game::teleport_player(&mut game, team, startX, startY);

            // Test move down
            game::test_player_action(&mut game, team, move_down, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (_x, y) = game::get_character_coords(&mut game, team);
            assert!(y == startY, EIncorrectCharacterCoordinates);

            // Test move right
            game::test_player_action(&mut game, team, move_right, scenario.ctx());
            assert!(game::test_is_character(&mut game, startX, startY), EIncorrectPlayerMovement);
            let (x, _y) = game::get_character_coords(&mut game, team);
            assert!(x == startX, EIncorrectCharacterCoordinates);

            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::end(scenario_val); // End the scenario and give back scenario_val
    }

    #[test, expected_failure(abort_code = ::gungame::game::EInvalidInput)]
    fun test_invalid_move() {
        let admin = @0xAD;
        let player1 = @0x01;
        let player2 = @0x02;

        let playerName = string::utf8(b"PlayerName");

        let mut scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            game::init_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, @0x0); // Must be this address or it fails
        {
            random::create_for_testing(scenario.ctx());
        };

        test_scenario::next_tx(scenario, admin);
        {
            let random = test_scenario::take_shared<Random>(scenario);
            let gmCap = scenario.take_from_sender<GameMasterCap>();
            game::make_game(&gmCap, 7, &random, scenario.ctx());
            scenario.return_to_sender(gmCap);
            test_scenario::return_shared<Random>(random);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            game::join_game(&mut game, playerName, scenario.ctx());
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, MOVE_RIGHT, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player2);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, MOVE_RIGHT, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::next_tx(scenario, player1);
        {
            let mut game = test_scenario::take_shared<Game>(scenario);
            let random = test_scenario::take_shared<Random>(scenario);
            game::play_game(&mut game, 10, &random, scenario.ctx());
            test_scenario::return_shared<Random>(random);
            test_scenario::return_shared<Game>(game);
        };

        test_scenario::end(scenario_val); // End the scenario and give back scenario_val
    }
}
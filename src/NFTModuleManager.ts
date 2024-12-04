import { SuiClient, SuiObjectResponse } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { Inputs } from '@mysten/sui.js/transactions';
import { ModuleManager } from '../lib/ModuleManager';

export class NFTModuleManager extends ModuleManager {
    constructor(packageId: string) {
        super(packageId);
    }

    public makeGame(txb: TransactionBlock, gameMasterCap: string, gridSize: number) {
        txb.moveCall({
            target: `${this.PACKAGE_ID}::game::make_game`,
            arguments: [
                txb.object(gameMasterCap),
                txb.pure(gridSize),
                txb.object('0x8') 
            ]
        });
    }

    public kickPlayer(txb: TransactionBlock, gameMasterCap: string, game: string, playerAddress: string) {
        txb.moveCall({
            target: `${this.PACKAGE_ID}::game::kick_player`,
            arguments: [
                txb.object(gameMasterCap),
                txb.object(game),
                txb.pure(playerAddress)
            ]
        });
    }

    public joinGame(txb: TransactionBlock, game: string, playerName: string) {
        txb.moveCall({
            target: `${this.PACKAGE_ID}::game::join_game`,
            arguments: [
                txb.object(game),
                txb.pure.string(playerName)
            ]
        });
    }

    public leaveGame(txb: TransactionBlock, game: string) {
        txb.moveCall({
            target: `${this.PACKAGE_ID}::game::leave_game`,
            arguments: [
                txb.object(game)
            ]
        });
    }

    public playGame(txb: TransactionBlock, game: string, playerChoice: string) {
        txb.moveCall({
            target: `${this.PACKAGE_ID}::game::play_game`,
            arguments: [
                txb.object(game),
                txb.pure(playerChoice),
                txb.object('0x8') 
            ]
        });
    }
}
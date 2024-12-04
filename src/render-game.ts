import { SuiClient } from "@mysten/sui.js/client";
import { NFTModuleManager } from "./NFTModuleManager";
import dotenv from 'dotenv';
import { getSuiClient, GRID_SIZE } from "./main";

// This takes the data returned and outputs the values into a grid
// It is very ugly due to type assertions
// Since I am storing the data as a Char in Move, it returns an ASCII number that needs to be converted back to char in TypeScript
export async function printGameBoard(suiClient: SuiClient, game: string, gridSize: number) {

    let objectContents = await NFTModuleManager.getObjectInfo(suiClient, game);

    const content = objectContents.data?.content!;

    if ("fields" in content && "grid" in content.fields) {
        for (let i = 0; i < gridSize; i++) {
            let row = "";
            for (let j = 0; j < gridSize; j++) {
                row += String.fromCharCode(((content.fields.grid as any[])[i] as any[])[j]) + " ";
            }
            console.log(row);
        }
    }
    console.log("-------------");
}

function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

export async function gameLoop() {
    dotenv.config();

    let gameObject: string = process.env.GAME_OBJECT ?? "";
    let url: string = process.env.RPC_URL ?? "";

    const suiClient: SuiClient = getSuiClient(url);

    while(true) {
        await printGameBoard(suiClient, gameObject, GRID_SIZE);
        await sleep(200);
    }
}

gameLoop();
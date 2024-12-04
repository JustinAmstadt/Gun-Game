import { NFTModuleManager } from "./NFTModuleManager";
import { PTBManager } from "../lib/PTBManager"
// @ts-ignore
import dotenv from 'dotenv';
// import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';
import { SuiClient, SuiHTTPTransport } from '@mysten/sui.js/client';
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { decodeSuiPrivateKey } from '@mysten/sui.js/cryptography';
import { TransactionBlock } from "@mysten/sui.js/transactions";
import * as readline from 'readline';

export const GRID_SIZE = 7;

const inputMap = new Map<string, string>();
inputMap.set("l", "0"); // Move left
inputMap.set("r", "1"); // Move right
inputMap.set("u", "2"); // Move up
inputMap.set("d", "3"); // Move down
inputMap.set("sl", "4"); // Shoot left
inputMap.set("sr", "5"); // Shoot right
inputMap.set("su", "6"); // Shoot up
inputMap.set("sd", "7"); // Shoot down

export function getKeyPair(privateKey: string): Ed25519Keypair {
  const decodedPrivateKey = decodeSuiPrivateKey(privateKey).secretKey;
  return Ed25519Keypair.fromSecretKey(decodedPrivateKey);
}

export async function signMultipleAndExecute(suiClient: SuiClient, txb: TransactionBlock, sponsor: Ed25519Keypair, keypair: Ed25519Keypair){
    const kindBytes = await txb.build({ client: suiClient, onlyTransactionKind: true });

    const sponsoredtx = TransactionBlock.fromKind(kindBytes);
    sponsoredtx.setSender(keypair.getPublicKey().toSuiAddress());
    sponsoredtx.setGasOwner(sponsor.getPublicKey().toSuiAddress());
    sponsoredtx.setGasPrice(1000);
    sponsoredtx.setGasBudget(10000000);

    const sponsoredBytes = await sponsoredtx.build({ client: suiClient });

    let sigArray: string[];

    if (sponsor.getPublicKey().toSuiAddress() === keypair.getPublicKey().toSuiAddress()) {
        let sponsorSig = await sponsor.signTransactionBlock(sponsoredBytes);
        sigArray = [sponsorSig.signature];
    } else {
        let sponsorSig = await sponsor.signTransactionBlock(sponsoredBytes);
        let keypairSig = await keypair.signTransactionBlock(sponsoredBytes);

        sigArray = [sponsorSig.signature, keypairSig.signature];
    }

    return suiClient.executeTransactionBlock({
        transactionBlock: sponsoredBytes,
        signature: sigArray,
    });
}

export function createSuiClient() {
    let mysten_rpc_url: string = process.env.MYSTEN_RPC_URL || '';
    let mysten_rpc_auth_type: string =
        process.env.MYSTEN_RPC_AUTH_TYPE || 'Basic';
    let mysten_rpc_auth_token: string =
        process.env.MYSTEN_RPC_AUTH_TOKEN || '';

    const transport_options: any = {
        url: mysten_rpc_url,
        rpc: {
            headers: {}
        }
    };

    if (mysten_rpc_auth_type === 'Bearer' || mysten_rpc_auth_type === 'Basic') {
        transport_options.rpc.headers.Authorization = `${mysten_rpc_auth_type} ${mysten_rpc_auth_token}`;
    }

    transport_options.rpc.headers['Content-Type'] = 'application/json';

    return new SuiClient({
        transport: new SuiHTTPTransport(transport_options),
    });
}

export function getSuiClient(url: string): SuiClient {
    return new SuiClient({ url: url });
}

// @ts-ignore
async function main() {
    dotenv.config();

    const secretKey: string = process.env.SECRET_KEY!;
    const keypair = getKeyPair(secretKey);
    const secretKey2: string = process.env.SECOND_SECRET_KEY!;
    const keypair2 = getKeyPair(secretKey2);

    let url: string = process.env.RPC_URL!;
    let playerName: string = process.env.PLAYER_NAME!;
    let gameMasterCap: string = process.env.GAME_MASTER_CAP ?? "";
    let gameObject: string = process.env.GAME_OBJECT ?? "";

    const suiClient: SuiClient = getSuiClient(url);

    const pk = keypair.getPublicKey();
    const sender = pk.toSuiAddress();

    const manager = new PTBManager(suiClient);

    const packageId = process.env.NFT_PACKAGE_ID!;
    if (packageId === undefined || packageId === '') {
        throw new Error("PACKAGE_ID is undefined in .env file");
    }

    const nftManager = new NFTModuleManager(packageId);

    const player1Name: string = "Player1";
    const player2Name: string = "Player2";

    let response;
    let output;

    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });

    /*
    nftManager.makeGame(manager.txb, gameMasterCap, GRID_SIZE);
    response = await signMultipleAndExecute(suiClient, manager.txb, keypair, keypair);
    output = await suiClient.waitForTransactionBlock({digest: response.digest, options: {showObjectChanges: true, showBalanceChanges: true, showEffects:  true, showEvents: true, showInput: true, showRawInput: true}});
    console.log(JSON.stringify(output, null, 2));
    manager.clearTransactionBlock();
    */

    try {
        nftManager.joinGame(manager.txb, gameObject, playerName);
        let response = await signMultipleAndExecute(suiClient, manager.txb, keypair, keypair2);
        let output = await suiClient.waitForTransactionBlock({digest: response.digest, options: {showObjectChanges: true, showBalanceChanges: true, showEffects:  true, showEvents: true, showInput: true, showRawInput: true}});
        console.log(JSON.stringify(output, null, 2))

        const joinedEvent = output.events![0].parsedJson!;
        if(typeof joinedEvent === 'object' && 'team' in joinedEvent) {
            console.log(`You are on team ${joinedEvent.team}!`);
        }
    } catch (e) {
        console.log("Exception: " + e);
        console.log("This is most like due to the player already being in the game");
    }

    manager.clearTransactionBlock();

    async function getInput() {
        rl.question('Please enter some input: ', async (playerChoice) => {

            let input = inputMap.get(playerChoice);

            if(input !== undefined) {
                nftManager.playGame(manager.txb, gameObject, input);
                response = await signMultipleAndExecute(suiClient, manager.txb, keypair, keypair2);
                let output = await suiClient.waitForTransactionBlock({digest: response.digest, options: {showObjectChanges: true, showBalanceChanges: true, showEffects:  true, showEvents: true, showInput: true, showRawInput: true}});
                // console.log(JSON.stringify(output, null, 2))
                manager.clearTransactionBlock();
            }

            getInput(); // Recursively call to ask for the next input
        });
    }

    await getInput();

    /*
    output.objectChanges?.map(async obj => {
        if ("created" === obj.type && typeof obj.owner === 'object' && 'AddressOwner' in obj.owner) {
            let objectContents = await NFTModuleManager.getObjectInfo(suiClient,obj.objectId);

            console.log(JSON.stringify(objectContents.data, null, 2));
        }
    });
    */
}

main();

import { SuiClient, SuiTransactionBlockResponse } from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { TransactionBlock } from "@mysten/sui.js/transactions";

/*
    USAGE:
    initTransaction(...)

    Calls to fill the block such as:
    txb.moveCall({
            target: `${PACKAGE_ID}::${MODULE_NAME}::${FUNCTION_NAME}`,
            arguments: [txb.pure.string(name), txb.pure.string(description), txb.pure.string(cry)]
    });

    executeTransactionBlock(...)

    The transaction block won't clear after, so you must call:
    clearTransactionBlock()
 */

export class PTBManager {
    public txb: TransactionBlock;
    public suiClient: SuiClient;

    constructor(client: SuiClient) {
        this.txb = new TransactionBlock();
        this.suiClient = client;
    }

    /* Run this first */
    public initTransaction(sender: string, gasPrice: number, gasBudget: number) {
        this.txb.setSender(sender);
        this.txb.setGasPrice(gasPrice);
        this.txb.setGasBudget(gasBudget);
    }

    /* Run this once the transaction block is loaded */
    // @ts-ignore
    public async executeTransaction(keypair: Ed25519Keypair) : Promise<SuiTransactionBlockResponse> {
        if (this.txb.blockData.transactions.length === 0) {
            console.log("Your transaction block is empty! This may succeed, but nothing will happen :)");
        }

        const bytes = await this.txb.build({ client: this.suiClient });
        const serializedSignature = (await keypair.signTransactionBlock(bytes)).signature;

        const response = this.suiClient.executeTransactionBlock({
            transactionBlock: bytes,
            signature: serializedSignature
        })

        return response;
    }

    /* The transaction block isn't cleared after it was executed, so clear it if desired */
    public clearTransactionBlock() {
        this.txb = new TransactionBlock();
    }
}
import { SuiClient, SuiObjectResponse } from '@mysten/sui.js/client';

export abstract class ModuleManager {
    public PACKAGE_ID: string;

    constructor(packageId: string) {
        this.PACKAGE_ID = packageId;
    }

    public static async getObjectInfo(suiClient: SuiClient, objectID: string) : Promise<SuiObjectResponse> {
        return suiClient.getObject({ 
            id: objectID, 
            options: { 
                showContent: true,
                /*
                showBcs: true,
                showDisplay: true,
                showOwner: true,
                showPreviousTransaction: true,
                showStorageRebate: true,
                showType: true,
                */
            }
        })
    }
}
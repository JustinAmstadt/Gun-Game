import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { Secp256k1Keypair } from "@mysten/sui.js/keypairs/secp256k1"
import { Secp256r1Keypair } from "@mysten/sui.js/keypairs/secp256r1"
import { fromB64 } from "@mysten/bcs";

/*  
    The keys are found in ~/.sui/sui_config/sui.keystore
    My keys are 45 characters long and they both start with AK
*/
export class KeypairManager {
    public static getEd25519KeypairFromSecretKey(key: string) : Ed25519Keypair {
        const raw = fromB64(key);
        return Ed25519Keypair.fromSecretKey(raw.slice(1));
    }

    public static getSecp256k1KeypairFromSecretKey(key: string) : Secp256k1Keypair {
        const raw = fromB64(key);
        return Secp256k1Keypair.fromSecretKey(raw.slice(1));
    }

    public static getSecp256r1KeypairFromSecretKey(key: string) : Secp256r1Keypair {
        const raw = fromB64(key);
        return Secp256r1Keypair.fromSecretKey(raw.slice(1));
    }
}
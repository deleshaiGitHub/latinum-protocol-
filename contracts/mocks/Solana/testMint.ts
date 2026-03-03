import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, SystemProgram, SYSVAR_RENT_PUBKEY } from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, getAssociatedTokenAddress } from "@solana/spl-token";
import { LatinumRemotePress } from "../target/types/latinum_remote_press";

// ===== CONSTANTS =====
const USDC_MINT_DEVNET = new PublicKey("4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU");
const BASE_SEPOLIA_EVM_ADDRESS = "0x41ab2B71D5d4E6b68eeBd1BA2272eD50D436f105";

async function main() {
    console.log("Testing Cross-Chain Mint...");

    const provider = anchor.AnchorProvider.env();
    anchor.setProvider(provider);
    
    const program = anchor.workspace.LatinumRemotePress as Program<LatinumRemotePress>;
    const user = provider.wallet.publicKey;

    const [solanaTreasuryPDA] = PublicKey.findProgramAddressSync(
        [Buffer.from("solana_treasury_solana_v4")],  // Changed to v2
        program.programId
    );

    const [nagusVaultPDA] = PublicKey.findProgramAddressSync(
        [Buffer.from("nagus_vault_solana_v5")],  // Changed to v2
        program.programId
    );

    const userUsdcATA = await getAssociatedTokenAddress(USDC_MINT_DEVNET, user);

    console.log("User:", user.toString());
    console.log("USDC ATA:", userUsdcATA.toString());

    // Convert EVM address to bytes32
    const evmAddressBytes = Buffer.from(BASE_SEPOLIA_EVM_ADDRESS.replace("0x", ""), "hex");
    const evmDestination = new Uint8Array(32);
    evmDestination.set(evmAddressBytes, 12);

    const USDC_AMOUNT = new anchor.BN(100_000); // 1 USDC

    const tx = await program.methods
        .mintGplToEvm(Array.from(evmDestination), USDC_AMOUNT)
        .accounts({
            user: user,
            userUsdc: userUsdcATA,
            userLamports: user,
            solanaTreasury: solanaTreasuryPDA,
            nagusVault: nagusVaultPDA,
            usdcMint: USDC_MINT_DEVNET,
            baseHubAddress: new PublicKey("11111111111111111111111111111111"),
            lzEndpoint: new PublicKey("76y77prYMDv2Ao5Q5j7jG1CnTRVvzCv3pQJ7PvP3vJk"),
            tokenProgram: TOKEN_PROGRAM_ID,
            systemProgram: SystemProgram.programId,
            rent: SYSVAR_RENT_PUBKEY,
        } as any )
        .rpc();

    console.log("Mint Tx:", tx);
}

main();
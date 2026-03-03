use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer, Mint}; 

declare_id!("DbY627K1p6y1eXGqXe4UTm7o8aWMywu2RPZ1Vm5nTfqW");

const LZ_ENDPOINT_ID: Pubkey = anchor_lang::solana_program::pubkey::Pubkey::from_str_const("76y77prYMDv2Ao5Q5j7jG1CnTRVvzCv3pQJ7PvP3vJk");
const BASE_SEPOLIA_EID: u32 = 40245;

#[program]
pub mod latinum_remote_press {
    use super::*;

    pub fn initialize(_ctx: Context<Initialize>) -> Result<()> {
        msg!("Latinum Protocol Solana Treasuries Initialized.");
        Ok(())
    }

    pub fn mint_gpl_to_evm(
        ctx: Context<MintGPL>,
        evm_destination: [u8; 32],
        usdc_amount: u64,
    ) -> Result<()> {
        require!(usdc_amount > 0, ErrorCode::ZeroAmount);
        
        let nagus_fee = (usdc_amount as u128)
            .checked_mul(25)
            .unwrap()
            .checked_div(10000)
            .unwrap() as u64;
        
        let treasury_amount = usdc_amount
            .checked_sub(nagus_fee)
            .ok_or(ErrorCode::MathOverflow)?;

        // Transfer to treasury
        token::transfer(
            CpiContext::new(
                ctx.accounts.token_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.user_usdc.to_account_info(),
                    to: ctx.accounts.solana_treasury.to_account_info(),
                    authority: ctx.accounts.user.to_account_info(),
                },
            ),
            treasury_amount,
        )?;

        // Transfer Nagus fee (COMMENTED OUT FOR TESTING)
        // if nagus_fee > 0 {
        //     token::transfer(
        //         CpiContext::new(
        //             ctx.accounts.token_program.to_account_info(),
        //             Transfer {
        //                 from: ctx.accounts.user_usdc.to_account_info(),
        //                 to: ctx.accounts.nagus_vault.to_account_info(),
        //                 authority: ctx.accounts.user.to_account_info(),
        //             },
        //         ),
        //         nagus_fee,
        //     )?;
        // }

        emit!(RemoteMintEvent {
            solana_user: ctx.accounts.user.key(),
            evm_destination,
            usdc_amount,
            nagus_fee,
            timestamp: Clock::get()?.unix_timestamp,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub user: Signer<'info>,

    #[account(
        init_if_needed,
        payer = user,
        token::mint = usdc_mint,
        token::authority = solana_treasury,
        seeds = [b"solana_treasury_solana_v4"],
        bump
    )]
    pub solana_treasury: Account<'info, TokenAccount>,
    
    #[account(
        init_if_needed,
        payer = user,
        token::mint = usdc_mint,
        token::authority = nagus_vault,
        seeds = [b"nagus_vault_solana_v5"],
        bump
    )]
    pub nagus_vault: Account<'info, TokenAccount>,

    pub usdc_mint: Account<'info, Mint>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[derive(Accounts)]
pub struct MintGPL<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        mut,
        constraint = user_usdc.owner == user.key(),
        constraint = user_usdc.mint == usdc_mint.key()
    )]
    pub user_usdc: Account<'info, TokenAccount>, 
    
    #[account(mut)]
    pub user_lamports: SystemAccount<'info>,
    
    #[account(
        mut,
        seeds = [b"solana_treasury_solana_v4"], 
        bump,
        token::mint = usdc_mint,
        token::authority = solana_treasury,
    )]
    pub solana_treasury: Account<'info, TokenAccount>, 
    
    #[account(
        mut,
        seeds = [b"nagus_vault_solana_v5"], 
        bump,
        token::mint = usdc_mint, 
        token::authority = nagus_vault,
    )]
    pub nagus_vault: Account<'info, TokenAccount>, 
    
    pub usdc_mint: Account<'info, Mint>,
    
    /// CHECK: This is the Base Hub contract address
    pub base_hub_address: UncheckedAccount<'info>,
    
    /// CHECK: LayerZero endpoint program
    #[account(address = LZ_ENDPOINT_ID)]
    pub lz_endpoint: UncheckedAccount<'info>,
    
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

#[event]
pub struct RemoteMintEvent {
    pub solana_user: Pubkey,
    pub evm_destination: [u8; 32],
    pub usdc_amount: u64,
    pub nagus_fee: u64,
    pub timestamp: i64,
}

#[error_code]
pub enum ErrorCode {
    #[msg("Amount must be greater than 0")]
    ZeroAmount,
    #[msg("Math overflow")]
    MathOverflow,
    #[msg("Insufficient SOL for cross-chain fee")]
    InsufficientSolForFee,
}
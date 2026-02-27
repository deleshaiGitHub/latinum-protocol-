# 🏛️ Latinum Protocol: Technical Architecture & File Map

This document serves as the structural source of truth for AI Development Agents (Cursor, Claude, GPT). All code generation must adhere to this hierarchy.

## 📁 Folder Hierarchy
- `/contracts`: Core logic.
    - `/contracts/core`: $GPL (OFT-V2) Token.
    - `/contracts/press`: Minting & Treasury logic.
    - `/contracts/treasury`: Nagus Insurance & Continuum vaults.
- `/frontend`: Next.js 14 Interface.
    - `/frontend/src/hooks`: Omnichain & Minting logic hooks.
- `/DOCS`: Development specifications.

## 📜 AI Context Rules (.cursorrules)
1. **Standard**: Solidity 0.8.24+, LayerZero V2 OFT.
2. **Cap**: 500,000,000,000 $GPL.
3. **Fee**: 0.25% Nagus Reserve on every mint.
4. **Logic**: Reference `DEV_WHITEPAPER_V1.md` for all math.

## 📍 Integration Map
- **Cross-Chain**: LayerZero V2.
- **DEX Aggregator**: Squid Router / Li.Fi SDK.
- **Stablecoin**: USDC (Primary Backing).

## ⚖️ Finalized Logic Constants (v1.1)
- MINT_RATE = 500,000 (1 USDC : 500k GPL)
- MAX_SUPPLY = 500,000,000,000 * 10**18
- SOFT_THRESHOLD = 250,000 * 10**6 (USDC 6-decimal standard)
- HARD_CAP = 1,000,000 * 10**6
- PLAN_B_TIMER = 180 Days
- EXIT_TAX = 5% (Rule #1)
- NAGUS_FEE = 0.25% (Auto-Buy/Burn)

DEV_WHITEPAPER_V1.3 (The "Ironclad" Amendment)
Add this section to your ARCHITECTURE.md/WHITEPAPER.md:
8. Security & Emergency Protocols (The "Jarvis" Shield)

    8.1 Manual Kill Switch (emergencyAbort): The Protocol Architect retains a manual override to stop minting and enable the Refund Phase if market conditions or technical hurdles jeopardize the $1M Treasury goal.
    8.2 Pull-Based Redemptions: To prevent "Gas Exhaustion" of the Treasury, the Protocol will never "push" refunds to users. Users must initiate a claimRefund() transaction. This ensures the protocol remains solvent regardless of the number of participants.
    8.3 The "Cost of Business" Refund (Option B): In an Abort scenario, users are refunded their Net Deposit (99.75%). The 0.25% Nagus Fee is considered a non-refundable protocol entry cost, ensuring the Nagus Insurance Vault remains capitalized for future iterations.
    8.4 Reentrancy Protection: All value-moving functions (mintGPL, claimRefund) follow the Checks-Effects-Interactions pattern. Internal state (balances) is zeroed before external transfers occur.
    8.5 Governance Evolution: Post-Beta, the onlyOwner modifier will be transferred from a "Hot Wallet" to a Gnosis Safe Multisig on Base.


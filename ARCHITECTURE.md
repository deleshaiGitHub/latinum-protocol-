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

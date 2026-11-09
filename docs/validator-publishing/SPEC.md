# Validator Publishing: specification

Status: draft for engineering review
Scope: DP-PRA-381, Exhibit A, section C (Validator Publishing)

## 1. Goal and non-goals

Starknet validators run Pragma's publisher next to their staking node and publish prices signed by a dedicated oracle account tied to their staker identity. During an opt-in pilot, their prices are published on mainnet in **shadow**: they are aggregated and compared with the production oracle, but no consumer reads them and they never enter the production median.

Non-goals:

- No change to the production Oracle or PublisherRegistry contracts, their admin, or their publishers.
- No consensus integration and no staking-reward change. Both remain separate decisions, informed by the pilot results.
- Operator payments are defined in section D of the agreement, not here.

## 2. Architecture

```
operator host
  staking node (Juno | Pathfinder) ── attestation tool (operational key, unchanged)
        │ JSON-RPC 0.10, local
        └── validator-publisher (oracle signer key)
                 │ publish_data_entries
                 ▼
Starknet mainnet
  Pilot Oracle (production Oracle class, unmodified) ──► ValidatorRegistry ──► Staking contract
  Production Oracle + PublisherRegistry (untouched)

Pragma
  comparator (pragma-monitoring): operator vs stake-weighted vs production vs independent reference
  correlated-failure alerting, operator manifest, staged releases
```

Why a separate pilot Oracle instance: the production Oracle takes a median per source across all registered publishers, then a median across every source published on a pair, and publisher permissions are per source, not per pair. A validator registered in the production registry would therefore move production prices. The pilot instance reuses the production Oracle class as is, so aggregation, storage and gas costs are identical to production.

## 3. Identity and keys

Starknet staking separates the validator's keys. The oracle signer is a fourth key that follows the same rules:

- **Staker address** (cold): validator identity. It binds, rotates and revokes the oracle signer. It never runs on the publisher host.
- **Reward address** (cold): unchanged.
- **Operational address** (hot): attestation only. It must not be the oracle signer.
- **Oracle signer** (hot): a dedicated Starknet account with a plain Stark signature that only signs `publish_data_entries` on the pilot Oracle, funded with STRK for gas.

The publisher id is the staker address as a felt (`publisher == staker_address`). Anyone can therefore check which validator published an entry.

### 3.1 Registration

This mirrors the staking contract's `declare_operational_address` / `change_operational_address` flow:

1. The oracle signer account calls `declare_oracle_signer(staker_address)`.
2. The staker address calls `bind_oracle_signer(oracle_signer)`. The call checks that:
   - the caller is a staker (`get_staker_info_v1` returns `Some`);
   - the staker is not exiting (`unstake_time` is `None`);
   - `amount_own >= min_self_stake`;
   - the signer was declared for this staker;
   - the signer is not the staker, reward or operational address;
   - the signer is not bound to another staker.

No Pragma action is required, so opt-in is self-service.

### 3.2 Rotation

The new signer declares itself and the staker binds it. The old signer is released in the same transaction.

### 3.3 Revocation

- **By the staker**: `revoke_oracle_signer(staker)`.
- **By the oracle signer itself**: same entry point. This is the emergency kill used when the hot key is suspected compromised.
- **Automatic, at publish time**: `get_publisher_address` returns zero, so the Oracle rejects the entries, when the staker:
  - has an unstake intent;
  - is deleted from staking;
  - has a self-stake below the minimum;
  - has changed its operational or reward address to the oracle signer (key reuse).
- **Permissionless cleanup**: `prune(staker)` for permanent states (not a staker, exiting, key reused).
- **Pilot kill switches** (admin): `set_suspended(staker, bool)` and `set_paused(bool)`.

Entries already stored stay in the pilot median for at most the Oracle's 1-hour freshness buffer (`BACKWARD_TIMESTAMP_BUFFER`).

## 4. Contracts

### 4.1 ValidatorRegistry

Source: `validator-registry/src/validator_registry.cairo`, a standalone Scarb package built with Cairo 2.11 (Sierra 1.7.0). Starknet only accepts declaring Sierra 1.5.0 to 1.9.0; the `pragma-oracle` package (Cairo 2.2) produces Sierra 1.3.0.

The Oracle-facing views are selector-compatible with `IPublisherRegistryABI`:

- `get_publisher_address(publisher) -> ContractAddress`: the signer if the publisher is `ACTIVE`, zero otherwise.
- `can_publish_source(publisher, source) -> bool`: the publisher is bound and the source is allowed.
- `get_publisher_sources(publisher)`, `get_all_publishers()`, `get_admin_address()`.

Validator flow: `declare_oracle_signer`, `bind_oracle_signer`, `revoke_oracle_signer`, `prune`.

Views:

- `get_publisher_status(staker)` returns one of `ACTIVE`, `PAUSED`, `NOT_BOUND`, `SUSPENDED`, `NOT_STAKER`, `EXITING`, `LOW_SELF_STAKE`, `KEY_REUSED`.
- `get_oracle_signer`, `get_staker_for_signer`, `get_declared_staker`, `get_allowed_sources`, `get_min_self_stake`, `get_staking_contract`, `is_paused`, `is_suspended`.

Admin: `set_allowed_sources`, `set_min_self_stake`, `set_suspended`, `set_paused`, `set_admin_address`.

Events: `OracleSignerDeclared`, `OracleSignerBound` (staker, old, new), `OracleSignerRevoked` (staker, signer, reason), `AllowedSourcesUpdated`, `MinSelfStakeUpdated`, `SuspensionUpdated`, `PauseUpdated`, `TransferOwnership`.

Staking dependency: only `get_staker_info_v1`, using the ABI deployed on mainnet and sepolia (`@staking/contracts-v1.0.1-dev.854`). The Serde layout was checked against a live mainnet call. The Staking v3 views (`staker_info_v3`, `get_stakers`) are not deployed and are not used.

### 4.2 Pilot Oracle

- An instance of the Oracle class already declared and running in production on each network (mainnet `0x04d6370214accdaac8cc249db34a916c92464235b87cf03641a85889d2f6d8e7`, sepolia `0x069f78c514b85543dbbc056a539e6b007cc37300892889be9d7ce9d5d5a21efb`), deployed with `ValidatorRegistry` as its publisher registry. No Oracle class is declared for the pilot.
- Pairs: assets that meet the four-source rule of section B, starting with BTC/USD, ETH/USD, STRK/USD, USDC/USD and USDT/USD.
- Allowed sources: market venues only, so source overlap between operators is measurable and aggregators are not counted as markets (section B): BINANCE, BITGET, BITSTAMP, BYBIT, GATEIO, HUOBI, KUCOIN, LBANK, OKX, UPBIT, EKUBO. On 2026-11-03 this left 9 sources for BTC/USD, 10 for ETH/USD, 8 for STRK/USD, 9 for USDC/USD and 5 for USDT/USD.
- Initial `min_self_stake`: 20,000 STRK (the protocol minimum).

### 4.3 Deployments

Script: `pragma-deployer/scripts/deploy_validator_pilot.py`. It writes `deployments/<network>/validator_pilot.json`. On devnet it also replays the registration flow end to end against the real Oracle class and a mock staking contract.

Sepolia, deployed on 2026-11-04:

- ValidatorRegistry: `0x056f2c0121bbd89983de8e6a300966115c7b7692a1ba38546d6cc2036b92ab58` (class `0x219b8602ef9523f41998b9281c6414a757918716b61fdf9d24072873349d8c0`)
- Pilot Oracle: `0x0417c6079b630414c223b2567c3d786c2abe9fa189e11c8cb3455f602044f658`
- Admin: `0x008ab21e4798ca47b17a86b0f68c4051768d2855691b59b5d515643d5a55eaa4`
- Minimum self-stake: 1 STRK, the Sepolia protocol minimum

### 4.4 Admin

The pilot contracts are administered by a Pragma account, whose address is published, so the pilot can be suspended or paused quickly. Pilot admin powers are limited to sources, minimum self-stake, suspension and pause. Admin cannot bind a signer for a validator. The production Oracle and PublisherRegistry keep the 3-of-4 multisig of section A.

## 5. Client: validator-publisher

An open-source package in `astraly-labs/pragma-sdk` that reuses the price-pusher architecture: fetchers, `FetcherClient`, poller, listener, pusher, orchestrator, health server and metrics.

### 5.1 Packaging

- Docker image `ghcr.io/astraly-labs/pragma-sdk/validator-publisher:<version>`, referenced by digest.
- Reference docker-compose snippets for Juno + Nethermind's attestation tool and for Pathfinder + Software Mansion's attestation tool.
- The image does not include the Miden client.

### 5.2 CLI

- `init`: writes a config file. The oracle signer account and its keystore are created with the operator's usual tooling (starkli, Argent, Braavos), as described in the runbook.
- `register`: sends `declare_oracle_signer` from the oracle signer, then prints the `bind_oracle_signer` calldata for the staker to sign in its own wallet. The client never handles the staker key.
- `preflight`: runs the checks in 5.4 and exits non-zero on failure.
- `run`: starts publishing.
- `status`: shows registry status, last pushes, balance and version.
- `rotate`, `revoke`.

### 5.3 Config

- YAML with `schema_version`. The client refuses unknown versions and accepts N-1.
- Fields:
  - `network`
  - `rpc_url` (the operator's own node)
  - `staker_address`
  - `keystore` (path, or a remote-signer URL compatible with the attestation tools' `/sign` API)
  - `pairs` (from the pilot list only)
  - `time_difference`
  - `price_deviation`
  - `health_port`
  - `metrics_port`
- The pilot Oracle and registry addresses are fixed per release, not configurable.

### 5.4 Preflight checks

1. The chain id matches `network`, and the node serves JSON-RPC 0.10 and is synced (head within N blocks of a public reference).
2. The oracle signer account is deployed and validates a plain Stark signature, and its STRK balance is above the threshold.
3. Key separation: the oracle signer differs from the staker, reward and operational addresses, read from `get_staker_info_v1`.
4. Registry status is `ACTIVE`, `get_oracle_signer(staker)` equals the local signer, and the staker is not exiting.
5. The configured pairs are pilot pairs, and the sources the client will publish are a subset of `get_allowed_sources`.
6. The clock is within 30 s of the latest block timestamp, because the Oracle validates entry timestamps.
7. A dry-run fetch:
   - every pair reaches the four-source quorum;
   - no fetcher reads any Pragma on-chain median;
   - the median of each pair is within 2% of an independent reference (direct venue prices).

### 5.5 Runtime behaviour

- The publish decision is made against the operator's own last entries (`get_data_entry(source, publisher)`), not the aggregated median. Otherwise operators would never push while other publishers keep the feed fresh.
- All Starknet reads, including on-chain fetchers, go through the operator's node. There is no silent fallback to public RPCs.
- Section B rules apply where the agreement puts them. The quorum counts underlying markets, not publisher processes, so it is applied to the feed, not to each publisher:
  - **In the client.** Quotes are converted with a measured USDT/USD rate: 4 reference venues, the last verified rate reused for 300 s at most, then converted pairs are not published. The client publishes every allowed source that answered and never withholds a pair below four sources. Every operator runs the same fetchers, so a source outage hits all of them at once: withholding per publisher would turn it into a stale feed. `validator_publisher_pair_sources` reports the coverage.
  - **On the read path** (`pragma-validator feed-status`, the comparator, any consumer of the pilot):
    - only entries of `ACTIVE` operators, on sources the registry allows, count;
    - a value is given only when at least four markets hold an entry younger than 40 min, across operators. Below that it is `WITHHELD`;
    - with no fresh entry the feed is `STALE`;
    - publisher and market counts are reported separately.
  - The pilot Oracle runs the production class unchanged. It returns a median whatever the number of sources, and checks the registry only when an entry is published: without the read path rules, a revoked operator's last entries would stay in its median for up to an hour.
- Graceful shutdown on SIGTERM. Liveness reflects the poll loop and readiness reflects pushes.

### 5.6 Telemetry

Prometheus metrics:

- the existing pusher and fetcher metrics;
- `validator_publisher_build_info{version, config_hash}`;
- `validator_publisher_registry_status`;
- `validator_publisher_signer_balance_strk`;
- `validator_publisher_tx_failures_total{reason}`;
- `validator_publisher_pair_sources{pair}`: allowed sources that answered in the last poll.

Each release ships an `alerts.rules.yml` with the production pusher alerts.

Pragma collects no telemetry by default. The pilot asks operators to expose build info and health to Pragma's monitoring (opt-in, documented in the runbook).

## 6. Releases, upgrade and rollback

- Versions are tagged `validator-publisher-vX.Y.Z`.
- Images are built in CI from the tag and signed with cosign (keyless, GitHub OIDC), with an SBOM and build provenance attached.
- Release notes list config schema changes and preflight changes.
- **Staged releases**:
  1. Pragma's own validator (canary, at least 48 h).
  2. A first wave of operators.
  3. The remaining operators.

  A wave starts only when the previous one shows no regression in deviation, freshness or tx failures.
- **Upgrade**: pin the new digest, run `preflight`, restart. **Rollback**: pin the previous digest and restart. Configs stay N-1 compatible. No contract action is ever needed for a client rollback.
- Any material safety change to the client or the contracts restarts the 30-day observation window.

## 7. Aggregation comparison

The comparator reads every validator entry from the pilot Oracle and, once per staking epoch, a stake snapshot from the staking contract (`get_staker_info_v1`, `staker_pool_info`, `get_current_total_staking_power`).

Every series applies the read path rules of §5.5. For each pair and interval it computes:

- **Operator-based**: one vote per active operator. The median of each operator's own source median, with a minimum operator quorum. An operator votes in an interval only with four fresh markets of its own.
- **Stake-weighted**: a weighted median using protocol staking power, `w = 0.75 * strk_i / STRK + 0.25 * btc_i / BTC`. BTC token decimals are normalized; SolvBTC uses 18 decimals.
- **Capped stake-weighted**: the same, with each operator capped (5% proposed). Today 3 operators hold more than a third of staking power and 4 hold more than half, so an uncapped stake-weighted median is effectively set by about 4 entities.

Each series is compared with the production Oracle and with an independent reference (direct venue prices outside the publisher path).

Reported:

- deviation (median and p99);
- freshness;
- operator and source coverage;
- withheld intervals;
- cost per operator (gas);
- manipulation cost (the minimum number of operators and share of stake needed to move the result by X%).

The January–February 2027 run requires 30 consecutive days within the agreed freshness and deviation limits, with material discrepancies explained.

## 8. Shared dependencies and correlated failures

- **Operator manifest** (public, PR-based): legal entity and ownership, hosting provider and region, node client and version, attestation tool, enabled fetchers.
- **On-chain heuristics**: shared reward addresses, and common funding of operational or oracle signer accounts.
- **Observed sources**: read directly from the published entries per operator.
- **Alerting**:
  - k or more operators deviating in the same direction within the same window;
  - grouped by version, config_hash, source and hosting provider;
  - alerts are checked against the independent reference, not only against the pilot median.
- **Staged releases** (section 6) bound the impact of a bad release to one wave.

## 9. Security

Threats covered:

- **Oracle signer compromise**: the staker or the signer can revoke, and the impact is limited to the shadow pilot.
- **Staker key never exposed**: `register` only prints calldata.
- **Key reuse with operational or reward**: rejected at bind and auto-revoked afterwards.
- **Exiting or deleted stakers**: auto-revoked.
- **Sybil**: minimum self-stake, plus operator manifest review for the operator-based series.
- **Feedback loops**: no fetcher reads any Pragma on-chain median (enforced by test).
- **Supply chain**: signed images, pinned digests, SBOM.

An independent security review of the contracts and the client must be completed, with critical and high findings resolved, before mainnet use (December 2026).

## 10. Delivery mapping

- **October–November 2026**: client and onboarding flow, installable by an external operator from the runbook. Testnet operation, key rotation and revocation, source-quorum failure handling.
- **December 2026**: pilot with at least five independent operators (subject to funded participation), telemetry and dependency data, independent security review.
- **January–February 2027**: 30 consecutive days of mainnet shadow comparison and recovery tests, followed by the protocol-integration recommendation.

## 11. Decisions

Confirmed on 2026-11-03:

1. A separate pilot Oracle instance (unmodified production class) on top of the ValidatorRegistry.
2. On-chain publishing during the pilot, to measure real gas costs and on-chain behaviour.
3. Pilot admin: a Pragma account limited to the powers in 4.4.
4. `min_self_stake`: 20,000 STRK, the protocol minimum.
5. Cap of the capped stake-weighted series: 5% per operator.
6. Pilot gas: a capped reimbursement from the section D operator budget, subject to Foundation approval.

# validator-registry

Publisher registry of the validator publishing pilot (DP-PRA-381, scope C), see
`docs/validator-publishing/SPEC.md`.

Built with Cairo 2.11 (Sierra 1.7.0), apart from `pragma-oracle/` (Cairo 2.2): Starknet
only accepts declaring Sierra 1.5.0 to 1.9.0. The pilot Oracle is an instance of the
Oracle class already declared on each network, so nothing else needs declaring.

```bash
scarb build
scarb test
```

Deploy: `pragma-deployer/scripts/deploy_validator_pilot.py`.

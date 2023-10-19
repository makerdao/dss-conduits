# `dss-conduits`

![Foundry CI](https://github.com/makerdao/dss-conduits/actions/workflows/ci.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/makerdao/dss-conduits/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

The Conduit is a smart contract that facilitates the deployment of funds to yield bearing strategies as part of the DSS Allocator System. The Conduit has a standard interface, defined in the `dss-allocator` repo [here](https://github.com/makerdao/dss-allocator/blob/dev/src/interfaces/IAllocatorConduit.sol). There are intended to be many Conduit implementations, each with a different use case. All Conduits can be found in the `src` directory.

For technical documentation and further information on specific Conduits, please see the [wiki](https://github.com/makerdao/dss-conduits/wiki).

## Upgradeability

Since Conduits will likely require maintenance as their desired usage evolves, they will be upgradeable contracts, using [`upgradeable-proxy`](https://github.com/marsfoundation/upgradeable-proxy) for upgradeable logic. This is a non-transparent proxy contract that gives upgrade rights to the PauseProxy.

## Testing

To run the tests, do the following:

```
forge test
```

## Functionality

### `deposit`

The `deposit` function is used to move funds from a given `ilk`s `buffer` into the Conduit. From the Conduit, the funds can be deployed to a yield bearing strategy. This can happen atomically in the case of DeFi protocols, or can happen in a separate function call made by a permissioned actor in the case of Real World Asset strategies.

<p align="center">
  <img src="https://github.com/makerdao/dss-conduits/assets/44272939/ab0b6d46-9e05-40e0-ba6e-2c09244d08f4" height="500" />
</p>

### `withdraw`

The `withdraw` function is used to move funds from the Conduit into a given `ilk`s `buffer`. This can pull funds atomically from a yield bearing strategy in the case of DeFi protocols, or can pull the funds directly from the Conduit in the case of a Real World Asset strategy where the permissioned actor has returned the funds manually. Both situations require that there is available liquidity, which is why `maxWithdraw` exists. This view function should report the maximum amount of `asset` that can be withdrawn for a given `ilk`.

<p align="center">
  <img src="https://github.com/makerdao/dss-conduits/assets/44272939/fd8fc168-542c-48b8-b987-676a8076a7d9" height="500" />
</p>

## Disclaimer

This code belongs to the MakerDAO community and the Copyright for the code belongs to the Dai Foundation.

---

<p align="center">
  <img src="https://github.com/makerdao/dss-conduits/assets/44272939/88576038-e2e5-42c8-a8da-fecc2229db0c" height="50" />
</p>

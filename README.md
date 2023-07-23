# `dss-conduits`

![Foundry CI](https://github.com/makerdao/dss-conduits/actions/workflows/ci.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/makerdao/dss-conduits/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

The Conduit is a smart contract that facilitates the deployment of funds to yield bearing strategies as part of the DSS Allocator System. The Conduit has a standard interface, defined in the `dss-allocator` repo [here](https://github.com/makerdao/dss-allocator/blob/dev/src/interfaces/IAllocatorConduit.sol). There are intended to be many Conduit implementations, each with a different use case. All Conduits can be found in the `src` directory.

## Upgradeability

Since Conduits will likely require maintenance as their desired usage evolves, they will be upgradeable contracts, using [`upgradeable-proxy`](https://github.com/marsfoundation/upgradeable-proxy) for upgradeable logic. This is a non-transparent proxy contract that gives upgrade rights to the PauseProxy.

## Testing

To run the tests, do the following:

```
gcl git@github.com:makerdao/dss-conduits.git
cd dss-conduits
forge test
```

## Functionality 

### `deposit`

<p align="center">
  <img src="https://github.com/makerdao/dss-conduits/assets/44272939/ab0b6d46-9e05-40e0-ba6e-2c09244d08f4" height="500" />
</p>

### `withdraw`

<p align="center">
  <img src="https://github.com/makerdao/dss-conduits/assets/44272939/fd8fc168-542c-48b8-b987-676a8076a7d9" height="500" />
</p>

## Disclaimer

This code belongs to the MakerDAO community and the Copyright for the code belongs to the Dai Foundation.

---

<p align="center">
  <img src="https://github.com/makerdao/dss-conduits/assets/44272939/88576038-e2e5-42c8-a8da-fecc2229db0c" height="50" />
</p>

#!/usr/bin/env just --justfile

# load .env file
set dotenv-load

# pass recipe args as positional arguments to commands
set positional-arguments

set export

RPC_URL := env_var_or_default("RPC_URL", "")
VERIFIER_URL := env_var_or_default("VERIFIER_URL", "")
HELIOS_OWNER := env_var_or_default("HELIOS_OWNER", "")
HELIOS_GLOBALS := env_var_or_default("HELIOS_GLOBALS", "")
POOL_FACTORY := env_var_or_default("POOL_FACTORY", "")
BLENDED_POOL_FACTORY_LIBRARY := env_var_or_default("BLENDED_POOL_FACTORY_LIBRARY", "")
POOL_FACTORY_LIBRARY := env_var_or_default("POOL_FACTORY_LIBRARY", "")
POOL := env_var_or_default("POOL", "")
BLENDED_POOL := env_var_or_default("BLENDED_POOL", "")
HELIOS_USD := env_var_or_default("HELIOS_USD", "")
USDT := env_var_or_default("USDT", "")

_default:
  just --list

# utility functions
start_time := `date +%s`
_timer:
    @echo "Task executed in $(($(date +%s) - {{ start_time }})) seconds"

clean-all: && _timer
	forge clean
	rm -rf lcov.info
	rm -rf crytic-export
	rm -rf tests-results
	rm -rf output

remove-modules: && _timer
	rm -rf .gitmodules
	rm -rf .git/modules/*
	rm -rf lib
	touch .gitmodules
	git add .
	git commit -m "modules"

# Install the Modules
install: && _timer
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts

# Update Dependencies
update: && _timer
	forge update

remap: && _timer
	forge remappings > remappings.txt

# Builds
generate-abi: && _timer
    forge clean
    forge build --names --skip .t.sol .s.sol --extra-output-files abi --out output/abi

deploy-all: && _timer
	forge script ./script/DeployScript.s.sol:DeployScript --rpc-url {{ RPC_URL }} --broadcast -vvvv

verify-all: && _timer
	forge verify-contract {{ HELIOS_GLOBALS }} ./contracts/global/HeliosGlobals.sol:HeliosGlobals \
		--constructor-args `cast abi-encode "constructor(address)" {{ HELIOS_OWNER }}` \
		--verifier-url {{ VERIFIER_URL }} --watch

	forge verify-contract {{ POOL_FACTORY }} ./contracts/pool/PoolFactory.sol:PoolFactory \
		--constructor-args `cast abi-encode "constructor(address)" {{ HELIOS_GLOBALS }}` \
		--verifier-url {{ VERIFIER_URL }} --watch \
		--libraries ./contracts/library/PoolFactoryLibrary.sol:PoolFactoryLibrary:{{ POOL_FACTORY_LIBRARY }} \
		--libraries ./contracts/library/BlendedPoolFactoryLibrary.sol:BlendedPoolFactoryLibrary:{{ BLENDED_POOL_FACTORY_LIBRARY }}

	#SKIP IN PROD
	forge verify-contract {{ USDT }} ./tests/mocks/MockTokenERC20.sol:MockTokenERC20 \
		--constructor-args `cast abi-encode "constructor(string memory _name, string memory _symbol)" mUSDC mUSDC` \
		--verifier-url {{ VERIFIER_URL }} --watch

	forge verify-contract {{ HELIOS_USD }} ./contracts/token/HeliosUSD.sol:HeliosUSD \
		--constructor-args `cast abi-encode "constructor(address initialOwner)" {{ HELIOS_OWNER }}` \
		--verifier-url {{ VERIFIER_URL }} --watch

	forge verify-contract {{ BLENDED_POOL }} ./contracts/pool/BlendedPool.sol:BlendedPool \
		--constructor-args `cast abi-encode "constructor(address, uint256, uint256)" {{ USDT }} 86400 1000000000000000000` \
		--verifier-url {{ VERIFIER_URL }} --watch

	forge verify-contract {{ POOL }} ./contracts/pool/Pool.sol:Pool \
		--constructor-args `cast abi-encode "constructor(address, uint256, uint256, uint256)" {{ USDT }} 86400 1000000000000000000 100000000000000000000` \
		--verifier-url {{ VERIFIER_URL }} --watch

initialize-all: && _timer
	forge script ./script/InitializeScript.s.sol:InitializeScript --rpc-url {{ RPC_URL }} --broadcast -vvvv

format: && _timer
	forge fmt

build: && _timer
	forge clean
	forge remappings > remappings.txt
	forge build --names --sizes

test-all: && _timer
	forge test -vvvvv

test-single: && _timer
	forge test -vvvvv --match-contract BlendedPoolInvariant

test-gas: && _timer
    forge test --gas-report

coverage-all: && _timer
	forge coverage --report lcov
	genhtml -o tests-results/coverage_report --branch-coverage lcov.info --ignore-errors category

analyze: && _timer
    slither .

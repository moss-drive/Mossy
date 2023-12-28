import '@nomicfoundation/hardhat-chai-matchers'
import '@nomicfoundation/hardhat-ethers'
import '@nomicfoundation/hardhat-verify'
import '@typechain/hardhat'

import 'hardhat-deploy'
import 'hardhat-gas-reporter'
import 'solidity-coverage'
import 'hardhat-storage-layout'
import 'solidity-docgen'

import { config as dotenvConfig } from 'dotenv'
import { resolve } from 'path'

if (process.env.NODE_ENV != 'build') {
	require('./tasks')
}

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || './.env'
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) })

const accounts = {
	mnemonic: process.env.MNEMONIC || 'test test test test test test test test test test test test',
}

const config = {
	solidity: {
		overrides: {},
		compilers: [
			{
				version: '0.8.19',
				settings: {
					optimizer: {
						enabled: true,
						runs: 2000
					},
					outputSelection: {
						'*': {
							'*': ['storageLayout'],
						},
					},
				},
			}
		],
	},
	namedAccounts: {
		deployer: 0,
		simpleERC20Beneficiary: 1
	},
	networks: {
		mainnet: {
			url: 'https://eth.llamarpc.com',
			accounts,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			timeout: 100000
		},
		localhost: {
			url: 'http://127.0.0.1:8545',
			accounts,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			timeout: 100000
		},
		hardhat: {
			forking: {
				enabled: true,
				url: process.env.MAINNET,
			},
			accounts,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			chainId: 1337,
			mining: {
				auto: true,
				interval: 5000
			}
		},
		PGN: {
			url: 'https://rpc.publicgoods.network',
			chainId: 424,
			accounts
		},
		bsc: {
			url: 'https://rpc.ankr.com/bsc',
			accounts,
			chainId: 56,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			timeout: 100000
		},
		chapel: {
			url: 'https://bsctestapi.terminet.io/rpc',
			accounts,
			chainId: 97,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			timeout: 100000
		},
		goerli: {
			url: 'https://rpc.goerli.eth.gateway.fm',
			accounts,
			chainId: 5,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			timeout: 100000
		},
		polygon: {
			url: 'https://rpc-mainnet.matic.network',
			accounts,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			timeout: 100000
		},
		mumbai: {
			url: 'https://rpc.ankr.com/polygon_mumbai',
			accounts,
			gas: 'auto',
			gasPrice: 'auto',
			gasMultiplier: 1.3,
			timeout: 100000
		},
		'optimistic-sepolia': {
			url: 'https://opt-sepolia.g.alchemy.com/v2/W2Mb0zJiEVI8ziTVuoMuyAyKdlpZ0W0T',
			chainId: 11155420,
			accounts
		},
		optimistic: {
			url: 'https://opt-mainnet.g.alchemy.com/v2/uwFroxk2OBoMpOSrmkuHAOcl1Z_1HQy_',
			chainId: 10,
			accounts
		}
	},
	etherscan: {
		apiKey: {
			mainnet: process.env.APIKEY_MAINNET!,
			bsc: process.env.APIKEY_BSC!,
			polygon: process.env.APIKEY_POLYGON!,
			goerli: process.env.APIKEY_GOERLI!,
			bscTestnet: process.env.APIKEY_CHAPEL!,
			polygonMumbai: process.env.APIKEY_MUMBAI!
		}
	},
	paths: {
		deploy: 'deploy',
		artifacts: 'artifacts',
		cache: 'cache',
		sources: 'contracts',
		tests: 'test'
	},
	gasReporter: {
		currency: 'USD',
		gasPrice: 100,
		enabled: process.env.REPORT_GAS ? true : false,
		coinmarketcap: process.env.COINMARKETCAP_API_KEY,
		maxMethodDiff: 10,
	},
	docgen: {
		templates: './hbs',
		root: './',
		theme: 'markdown',
		sourcesDir: './contracts',
		pages: 'files',
		outputDir: './docs'
	},
	typechain: {
		outDir: 'types',
		target: 'ethers-v6',
	},
	mocha: {
		timeout: 0,
	}
}

export default config

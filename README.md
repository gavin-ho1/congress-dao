
# Congress DAO

Proof of Concept US Congress DAO Simulation on The Ethereum Blockchain

## Overview

This project is a proof of concept that simulates the United States Congress as a Decentralized Autonomous Organization (DAO) on the Ethereum blockchain. It aims to model the legislative process, allowing proposals to be submitted, voted on, and executed in a decentralized manner.

## Features

- **Proposal Submission**: Members can submit proposals for consideration.
- **Voting Mechanism**: Members can vote on proposals within a specified timeframe.
- **Execution**: Approved proposals are executed automatically on the blockchain.

## Project Structure

The repository is organized as follows:

- `contracts/`: Contains the Solidity smart contracts.
- `scripts/`: Deployment scripts for the contracts.
- `test/`: Test cases for the contracts.

## Getting Started

To get started with this project, follow these steps:

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/gavin-ho1/congress-dao.git
   cd congress-dao

2. **Install Dependencies**:
   Ensure you have [Node.js](https://nodejs.org/) and [npm](https://www.npmjs.com/) installed. Then, install the project dependencies:
   ```bash
   npm install
   ```

3. **Compile Contracts**:
   Use Hardhat to compile the smart contracts:
   ```bash
   npx hardhat compile
   ```

4. **Run Tests**:
   Execute the test cases to ensure everything is working correctly:
   ```bash
   npx hardhat test
   ```

5. **Deploy Contracts**:
   Deploy the contracts to a local network:
   ```bash
   npx hardhat node
   npx hardhat run scripts/deploy.js --network localhost
   ```

## Usage

After deploying the contracts, you can interact with them using the Hardhat console or by integrating them into a frontend application. The main contract to interact with is `Congress.sol`, which manages the proposal and voting processes.

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes. Ensure that your code adheres to the existing style and includes relevant tests.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

*Note: This project is for educational and experimental purposes only and is not intended for production use.*
```

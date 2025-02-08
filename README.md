
# CongressDAO

![Solidity](https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white)
<br>
Proof of Concept US Congress DAO Simulation on The Ethereum Blockchain

## Overview

This project is a proof of concept that simulates the United States Congress as a Decentralized Autonomous Organization (DAO) on the Ethereum blockchain. It aims to model the legislative process, allowing proposals to be submitted, voted on, and executed in a decentralized manner.

## Why a DAO?

CongressDAO aims to bring the traditional legislative process into the decentralized, transparent, and secure world of blockchain technology. Here’s how it enhances the current system:

- **Decentralization**: Unlike the traditional system, where decision-making and proposal submissions are centralized, a DAO allows every member to participate directly. This removes the influence of powerful lobbyists and ensures that decisions reflect the collective will of the participants.

- **Transparency**: In traditional Congress, the storage of bills and legislative actions can be opaque, with limited public access and complex procedures. With the CongressDAO, all proposals, votes, and decisions are recorded on the blockchain, ensuring full transparency and visibility to all participants and the public.

- **Accessibility**: One of the major challenges in traditional government is the limited accessibility for the average citizen to directly participate in legislative processes. The CongressDAO opens up the legislative process, enabling anyone with an internet connection to propose, vote on, and track legislation, promoting greater citizen engagement.

- **Security**: Storing bills and votes in centralized databases can be vulnerable to tampering and cyber attacks. With blockchain, each proposal, vote, and outcome is cryptographically secure and immutable, ensuring that the integrity of the process is preserved without reliance on a single point of failure.

- **Reduction of Costs**: Traditional legislative processes often involve significant administrative overhead—paperwork, manual tracking, and physical meetings. The CongressDAO eliminates many of these costs by automating and digitizing the entire process, making it faster and more cost-efficient while reducing reliance on bureaucratic processes.


## Features

- **Adding Members:** Simulated Congress members can be added (only available to the owner of the DAO) or nominated and the ratified by existing members.
- **Proposal Submission**: Simulated Congress members can submit proposals for consideration.
- **Voting Mechanism**: Simulated Congress members can vote on proposals within a specified timeframe.
- **Execution**: Approved proposals are automatically recorded on the blockchain.

## Project Structure

The repository is organized as follows:

- `contracts/`: Contains the Solidity smart contracts.
- `scripts/`: Deployment scripts for the contracts (Currently set as the defaults when working in remix ide).
- `test/`: Test cases for the contracts.

## Getting Started

To get started with this project, follow these steps:

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/gavin-ho1/congress-dao.git
   cd congress-dao
   ```

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

4. **Install Hardhat Gas Reporter (Optional)**:
   If you want to monitor gas usage, install Hardhat Gas Reporter:
   ```bash
   npm install --save-dev hardhat-gas-reporter
   ```
   Then, enable it in `hardhat.config.js` by adding:
   ```javascript
   require("hardhat-gas-reporter");

   module.exports = {
     solidity: "0.8.28",
     gasReporter: {
       enabled: true,
       token: "ETH",
       currency: 'USD',
       coinmarketcap: process.env.COINMARKETCAP_API_KEY, 
       L2Etherscan: process.env.ETHERSCAN_API_KEY,
       L1Etherscan: process.env.ETHERSCAN_API_KEY,
     },
   };
   ```

5. **Set Up Environment Variables**:
   Create a `.env` file in the root directory and add your API keys:
   ```bash
   touch .env
   ```

   Inside `.env`, add:
   ```
   COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

   Then, install `dotenv` to load environment variables:
   ```bash
   npm install dotenv
   ```

   Update `hardhat.config.js` to include:
   ```javascript
   require("dotenv").config();
   ```

6. **Run Tests**:
   Execute the test cases to ensure everything is working correctly:
   ```bash
   npx hardhat test
   ```

7. **Deploy Contracts**:
   Deploy the contracts to a local network:
   ```bash
   npx hardhat node
   npx hardhat run scripts/deploy.js --network localhost
   ```

## Usage

After deploying the contracts, you can interact with them using the Hardhat console or by integrating them into a frontend application. The main contract to interact with is `Congress.sol`, which manages the proposal and voting processes.

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes. Ensure that your code adheres to the existing style and includes relevant tests.

---

*Note: This project is for educational and experimental purposes only and is not intended for production use.*

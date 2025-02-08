const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("CongressDAOModule", (m) => {
  // Deploy the CongressDAO contract with no constructor parameters.
  const congressDAO = m.contract("CongressDAO", []);
  
  // Return the deployed contract instance so it can be accessed in tests or scripts.
  return { congressDAO };
});

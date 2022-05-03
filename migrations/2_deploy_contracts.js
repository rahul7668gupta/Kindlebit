var NFTListing = artifacts.require("./NFTListing.sol");

module.exports = function (deployer) {
  deployer.deploy(NFTListing);
};

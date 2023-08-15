const { upgradeProxy , deployImplementation , verifyImpContract} = require("./utils/upgrade_utils")
const proxyAddress = "0x75b34f5D1dedA3d5512D235a25634B242BE8aef1";
const contractName = "BnbxYieldConverterStrategy";

const main = async () => {

  console.log("Upgrading CeVaultV2...");
//   const ceVaultImpAddress = await deployImplementation("CerosETHRouter");

//     // upgrade Proxy
//     await upgradeProxy(proxyAddress, ceVaultImpAddress);

    await verifyImpContract("0x1CA61eb8Fb242387dD26A0F78D25ed6b81614300");    
};

main()
  .then(() => {
    console.log("Success");
  })
  .catch((err) => {
    console.log(err);
  });
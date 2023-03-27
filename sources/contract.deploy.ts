import { Address, beginCell, contractAddress, toNano } from "ton";
import { jetton_minter,  Mint, storeMint } from "./output/sample_jetton_minter";
import { deploy } from "./utils/deploy";
import { printAddress, printDeploy, printHeader } from "./utils/print";
import {buildOnchainMetadata} from "./utils/jetton-helpers";
import { fromNano } from "ton-core";


let deploy_address = Address.parse("");


(async () => {
    // Parameters
    const jettonParams = {
        name: "Test USD",
        symbol: "tUSDN",
        description: "This is description of Test tact jetton",
        image: "https://cdn.logo.com/hotlink-ok/logo-social.png" 
    };
    let content = buildOnchainMetadata(jettonParams);


    // let owner = deploy_address; // Replace owner with your address
    let packed = beginCell()
                    .store(
                        storeMint({ 
                            $$type: 'Mint',
                            amount: toNano("0.5")
                        }))
                .endCell(); // Replace if you want another message used

    let init = await jetton_minter.init(
        deploy_address,
        content,
        25000n,
        180n,  // after x days to end of selling
    );

    let address = contractAddress(0, init);
    let deployAmount = toNano("0.75");
    let testnet = true;

    // Print basics
    printHeader('SampleTactContract');
    // printDeploy(init, deployAmount, packed, testnet);
    
    // Do deploy
    await deploy(init, deployAmount, packed, testnet)


    printAddress(address);
})();
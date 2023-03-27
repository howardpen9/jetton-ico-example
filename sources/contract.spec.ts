import { fromNano, toNano, beginCell } from "ton";
import { ContractSystem } from "@tact-lang/emulator";
import { jetton_minter } from "./output/sample_jetton_minter";
import { buildOnchainMetadata } from "./utils/jetton-helpers";

const jettonParams = {
    name: "Test USD",
    symbol: "tUSDN",
    description: "This is description of Test tact jetton",
    image: "https://cdn.logo.com/hotlink-ok/logo-social.png",
};
let content = buildOnchainMetadata(jettonParams);

describe("contract", () => {
    it("should deploy correctly", async () => {
        // Create ContractSystem and deploy contract
        let system = await ContractSystem.create();
        let owner = system.treasure("owner");
        let nonOwner = system.treasure("non-owner");

        // let dataCell = beginCell().storeCoins(10000).endCell();

        let contract = system.open(
            await jetton_minter.fromInit(
                owner.address,
                content,
                2500n, // multiplier
                14n // after 14 days close the selling
            )
        );
        system.name(contract.address, "main_contract");
        let track = system.track(contract);
        await contract.send(
            owner,
            { value: toNano(3) }, // The Gas you pay
            {
                $$type: "Mint",
                amount: toNano("1"), // 1 TON
            }
        );
        await system.run();
        // expect(await contract.getTempValue()).toMatchInlineSnapshot(`2500000000000n`);
        expect(track.collect()).toMatchInlineSnapshot(`
            [
              {
                "$seq": 0,
                "events": [
                  {
                    "$type": "deploy",
                  },
                  {
                    "$type": "received",
                    "message": {
                      "body": {
                        "cell": "x{01FB345B000000000000000000000000000000000000000000000000000000001DCD65004_}",
                        "type": "cell",
                      },
                      "bounce": true,
                      "from": "@treasure(owner)",
                      "to": "@main_contract",
                      "type": "internal",
                      "value": 3000000000n,
                    },
                  },
                  {
                    "$type": "processed",
                    "gasUsed": 20446n,
                  },
                  {
                    "$type": "sent",
                    "messages": [
                      {
                        "body": {
                          "cell": "x{178D4519000000000000000060246139CA80080005F0CE5168A2D2E2DD7020977B6666F0A17998CEF5ECB378E20172C05702FB1100023EDC525573FCB04AE638BEAD1B62BCD1ED2E0E721E32EDB4D4FE2E722CE07702_}",
                          "type": "cell",
                        },
                        "bounce": true,
                        "from": "@main_contract",
                        "to": "kQDsovGhtQIn7YE2LigiHXCIhHOrW3XhXyOuzVS9hLkFUFtH",
                        "type": "internal",
                        "value": 1945000000n,
                      },
                    ],
                  },
                ],
              },
            ]
        `);
        // 0.960 000 000n
        // Check counter
        expect(await contract.getTempValue()).toMatchInlineSnapshot(`2500000000000n`);

        // Non-owner
        // await contract.send(nonOwner, { value: toNano(1) }, "increment");
        // await system.run();
        // expect(track.collect()).toMatchInlineSnapshot();
    });
});

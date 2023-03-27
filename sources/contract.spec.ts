import { fromNano, toNano } from "ton";
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
        let contract = system.open(await jetton_minter.fromInit(
            owner.address, 
            content, 
            10n  // Multiplier
          ));

        system.name(contract.address, "main_contract");
        let track = system.track(contract);

        await contract.send(
            owner,
            { value: toNano(2) }, // The Gas you pay 
            {
                $$type: "Mint",
                amount: toNano(1), // 1 TON
            }
        );

        await system.run();
        expect(await contract.getTempValue()).toMatchInlineSnapshot(`0n`);
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
                      "value": 2000000000n,
                    },
                  },
                  {
                    "$type": "failed",
                    "errorCode": 5,
                    "errorMessage": "Integer out of expected range",
                  },
                  {
                    "$type": "sent-bounced",
                    "message": {
                      "body": {
                        "cell": "x{FFFFFFFF01FB345B00000000000000000000000000000000000000000000000000000000}",
                        "type": "cell",
                      },
                      "bounce": false,
                      "from": "@main_contract",
                      "to": "@treasure(owner)",
                      "type": "internal",
                      "value": 1979547000n,
                    },
                  },
                ],
              },
            ]
        `);
        // 0.960 000 000n
        // Check counter
        expect(await contract.getTempValue()).toMatchInlineSnapshot(`0n`);

        // Non-owner
        // await contract.send(nonOwner, { value: toNano(1) }, "increment");
        // await system.run();
        // expect(track.collect()).toMatchInlineSnapshot();
    });
});

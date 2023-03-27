
// JuiceBox in TON
// User deposit funds and get voting power?
// or certain amount of nfts / jettons tokens. 
message Mint {
    amount: Int;
}

struct JettonData {
    totalSupply: Int;
    mintable: Bool;
    owner: Address;
    content: Cell;
    walletCode: Cell;
}

contract jetton_minter {
    const minTonsForStorage: Int = ton("0.02");
    const gasConsumption: Int = ton("0.02");
    owner_address: Address;
    total_supply: Int as uint128 = 0;
    content: Cell;
    mintable: Bool;
    weight: Int;

    days_expire: Int;
    start_unix: Int;
    
    init(owner_address: Address, content: Cell, weight: Int, days_expire: Int) {
        self.owner_address = owner_address;
        self.total_supply = 0;
        self.content = content;
        self.weight = weight;
        self.mintable = false;
        self.days_expire = days_expire;
        self.start_unix = 1670000000; // Unix check on https://www.unixtimestamp.com/
    }

    receive(msg: Mint) {
        let ctx: Context = context(); 
        require((now() - self.start_unix) / 86400 <= self.days_expire , "out of minting period");
        self.mint(ctx.sender, msg.amount);
    }

    get fun get_end_date(): Int {
        return self.start_unix + 86400 * self.days_expire;
    }

    fun mint(to: Address, amount: Int) {
        let ctx: Context = context(); 
        let msgValue: Int = self.msgValue(ctx.value);

        let jetton_amount: Int =  amount * self.weight;     
        let fee: Int = amount * 15 / 1000; // 1.5%  of TON     
        require(msgValue >= amount + fee, "TON is not enough...");
    
        self.total_supply = self.total_supply + jetton_amount;

        let winit: StateInit = self.getJettonWalletInit(to);
        send(SendParameters{
            to: contractAddress(winit), 
            value: msgValue - amount - fee,
            bounce: true,
            mode: SendPayGasSeparately,
            body: TokenTransferInternal{ 
                queryId: 0,
                amount: jetton_amount,
                from: myAddress(),
                response_destination: to,
                forward_ton_amount: 0,
                forward_payload: emptySlice()
            }.toCell(),
            code: winit.code,
            data: winit.data
        });
    }

    receive("Withdraw") {
        let ctx: Context = context(); 
        require(ctx.sender == self.owner_address, "not admin");
        send(SendParameters{
            to: ctx.sender,
            value: 0,
            bounce: false,
            mode: SendRemainingBalance,
            body: "Success".asComment()
        });
    }

    // ======== Get Methods ========//
    get fun get_jetton_data(): JettonData {
        let code: Cell = self.getJettonWalletInit(myAddress()).code;
        return JettonData{ 
            totalSupply: self.total_supply, 
            mintable: self.mintable,
            owner: self.owner_address, 
            content: self.content, 
            walletCode: code
        };
    }

    get fun get_wallet_address(owner: Address): Address {
        let winit: StateInit = self.getJettonWalletInit(owner);
        return contractAddress(winit);
    }

    // ======== Private Helper Functions ========= //
    fun getJettonWalletInit(address: Address): StateInit {
        return initOf JettonWallet(myAddress(), address);
    }

    fun msgValue(msgValue: Int): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        msgValue = msgValue - (storageFee + self.gasConsumption);
        return msgValue;
    }

    // get fun tempValue(): Int {
    //     return self.tempValue;
    // }
}


contract JettonWallet {
    const minTonsForStorage: Int = ton("0.01");
    const gasConsumption: Int = ton("0.015");
    master: Address;
    owner: Address;
    balance: Int;

    init(master: Address, owner: Address) {
        self.master = master;
        self.owner = owner;
        self.balance = 0;
    }

    receive(msg: TokenTransfer) { // 0xf8a7ea5
        let ctx: Context = context(); // Check sender
        require(ctx.sender == self.owner, "Invalid sender");

        let fwdFee: Int = ctx.readForwardFee() + ctx.readForwardFee();  // Gas checks
        let final: Int =  2 * self.gasConsumption + self.minTonsForStorage + fwdFee;
        require(ctx.value > min(final, ton("0.01")), "Invalid value!!"); 

        self.balance = self.balance - msg.amount; // Update balance
        require(self.balance >= 0, "Invalid balance");

        let init: StateInit = initOf JettonWallet(self.master, msg.destination);  
        let walletAddress: Address = contractAddress(init);
        send(SendParameters{
                to: walletAddress, 
                value: 0,
                mode: SendRemainingValue, 
                bounce: false,
                body: TokenTransferInternal{
                    queryId: msg.queryId,
                    amount: msg.amount,
                    from: self.owner,
                    response_destination: msg.response_destination,
                    forward_ton_amount: msg.forward_ton_amount,
                    forward_payload: msg.forward_payload
                }.toCell(),
                code: init.code,
                data: init.data
            });
    }

    receive(msg: TokenTransferInternal) { // 0x178d4519
        let ctx: Context = context();

        if (ctx.sender != self.master) {
            let sinit: StateInit = initOf JettonWallet(self.master, msg.from);
            require(contractAddress(sinit) == ctx.sender, "Invalid sender!");
        }

        self.balance = self.balance + msg.amount;
        require(self.balance >= 0, "Invalid balance"); // Update balance

        if (msg.forward_ton_amount > 0) { 
            send(SendParameters{
                to: self.owner,
                value: msg.forward_ton_amount,
                bounce: false,
                body: TokenNotification { // 0x7362d09c - notify new owner
                    queryId: msg.queryId,
                    amount: msg.amount,
                    from: msg.from,
                    forward_payload: msg.forward_payload
                }.toCell()
            });
        }

        let msgValue: Int = self.msgValue(ctx.value);  // Get value for gas
        msgValue = msgValue - msg.forward_ton_amount - min(ctx.readForwardFee(), ton("0.015"));

        if (msg.response_destination != null) { // Cashback
                send(SendParameters {
                    to: msg.response_destination, 
                    value: msgValue,  
                    bounce: false,
                    body: TokenExcesses { // 0xd53276db
                        queryId: msg.queryId
                    }.toCell(),
                    mode: SendIgnoreErrors
                });
        }
    }

    get fun msgValue(value: Int): Int {
        let msgValue: Int = value;
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        msgValue = msgValue - (storageFee + self.gasConsumption);
        return msgValue;
    }

    receive(msg: TokenBurn) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Invalid sender");  // Check sender

        self.balance = self.balance - msg.amount; // Update balance
        require(self.balance >= 0, "Invalid balance");

        let fwdFee: Int = ctx.readForwardFee(); // Gas checks
        require(ctx.value > fwdFee + 2 * self.gasConsumption + self.minTonsForStorage, "Invalid value - Burn");

        send(SendParameters{  // Burn tokens
            to: self.master,
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: TokenBurnNotification{
                queryId: msg.queryId,
                amount: msg.amount,
                owner: self.owner,
                response_destination: self.owner
            }.toCell()
        });
    }

    bounced(msg: Slice) {
        msg.skipBits(32); // 0xFFFFFFFF  // Parse bounced message
        let op: Int = msg.loadUint(32);
        let queryId: Int = msg.loadUint(64);
        let jettonAmount: Int = msg.loadCoins();
        require(op == 0x178d4519 || op == 0x7bdd97de, "Invalid bounced message");
        
        self.balance = self.balance + jettonAmount; // Update balance
    }

    get fun get_wallet_data(): JettonWalletData {
        return JettonWalletData{
            balance: self.balance,
            owner: self.owner,
            master: self.master,
            walletCode: (initOf JettonWallet(self.master, self.owner)).code
        };
    }
}


message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    response_destination: Address;
    custom_payload: Cell?;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining;
}

message(0x178d4519) TokenTransferInternal {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    response_destination: Address;
    forward_ton_amount: Int as coins;
    forward_payload: Slice as remaining;
}

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forward_payload: Slice as remaining; // Comment Text message when Transfer the jetton 
}

message(0x595f07bc) TokenBurn {
    queryId: Int as uint64;
    amount: Int as coins;
    owner: Address;
    response_destination: Address;
}

message(0x7bdd97de) TokenBurnNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    owner: Address;
    response_destination: Address?;
}

message(0xd53276db) TokenExcesses {
    queryId: Int as uint64;
}

message TokenUpdateContent {
    content: Cell;
}

struct JettonWalletData {
    balance: Int;
    owner: Address;
    master: Address;
    walletCode: Cell;
}
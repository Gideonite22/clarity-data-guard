// [Previous test content]

Clarinet.test({
  name: "Test data deletion functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const testHash = "a".repeat(64);
    
    // Store data
    let block = chain.mineBlock([
      Tx.contractCall('data-guard', 'store-data', [
        types.ascii(testHash)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Delete data
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'delete-data', [
        types.ascii(testHash)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  },
});

// [Include existing tests...]

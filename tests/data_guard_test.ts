// [Previous test content remains unchanged, adding new tests...]

Clarinet.test({
  name: "Test emergency revocation functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    // Grant access with emergency revocation enabled
    let block = chain.mineBlock([
      Tx.contractCall('data-guard', 'grant-access-with-expiry', [
        types.principal(user1.address),
        types.none(),
        types.bool(true)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test emergency revocation
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'emergency-revoke', [
        types.principal(deployer.address),
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify access is revoked
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'check-access', [
        types.principal(deployer.address),
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(false);
  },
});

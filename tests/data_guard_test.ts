import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure users can store data and manage access permissions",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const user2 = accounts.get('wallet_2')!;
    
    // Test storing data
    let block = chain.mineBlock([
      Tx.contractCall('data-guard', 'store-data', [
        types.ascii('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef')
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test granting access
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'grant-access', [
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Check grant count
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'get-grant-count', [
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectUint(1);
    
    // Verify access permission
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'check-access', [
        types.principal(deployer.address),
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Test revoking access
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'revoke-access', [
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Check grant count decreased
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'get-grant-count', [
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectUint(0);
    
    // Verify access revoked
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'check-access', [
        types.principal(deployer.address),
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(false);
  },
});

Clarinet.test({
  name: "Test grant count limit",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    let users = [];
    for(let i = 1; i <= 11; i++) {
      users.push(accounts.get(`wallet_${i}`)!);
    }
    
    // Grant access to 10 users (should succeed)
    for(let i = 0; i < 10; i++) {
      let block = chain.mineBlock([
        Tx.contractCall('data-guard', 'grant-access', [
          types.principal(users[i].address)
        ], deployer.address)
      ]);
      block.receipts[0].result.expectOk().expectBool(true);
    }
    
    // Try to grant access to 11th user (should fail)
    let block = chain.mineBlock([
      Tx.contractCall('data-guard', 'grant-access', [
        types.principal(users[10].address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectErr(105);
  },
});

Clarinet.test({
  name: "Test time-limited access control",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    
    // Grant access that expires in 10 blocks
    const currentHeight = chain.blockHeight;
    const expiryHeight = currentHeight + 10;
    
    let block = chain.mineBlock([
      Tx.contractCall('data-guard', 'grant-access-with-expiry', [
        types.principal(user1.address),
        types.some(types.uint(expiryHeight))
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Check access is granted
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'check-access', [
        types.principal(deployer.address),
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Mine 11 blocks to exceed expiry
    chain.mineEmptyBlockUntil(expiryHeight + 1);
    
    // Check access is now expired
    block = chain.mineBlock([
      Tx.contractCall('data-guard', 'check-access', [
        types.principal(deployer.address),
        types.principal(user1.address)
      ], deployer.address)
    ]);
    block.receipts[0].result.expectOk().expectBool(false);
  },
});

import fs from 'node:fs';
import path from 'node:path';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import { AnchorProvider, Program } from '@coral-xyz/anchor';

const rpc = process.env.RPC_URL;
const out = process.env.SNAPSHOT_DIR || process.cwd();
const connection = new Connection(rpc, {
  commitment: 'confirmed',
  confirmTransactionInitialTimeout: 60_000,
});
const PROGRAM = new PublicKey(process.env.BANKINECO_PROGRAM);
const addresses = {
  bankineco_program: process.env.BANKINECO_PROGRAM,
  marginfi_program: process.env.MARGINFI_PROGRAM,
  usd_star_bank: 'sM6P4mh53CnG4faN4Fo3seY7wMSAiHdy8o6gKjwQF7A',
  main_usdc_vault: '3bZ1qY6wfzyDH7QMPiRKLr6k8p1asdtyjvJyJsJBdv23',
  junior_tranche: 'hXfEYpB5FB3ZWjGNc5C5JqLixmGdmZFyjXKJB2xFPgc',
  usd_star_mint: 'star9agSpjiFe3M49B3RniVU4CMBBEK3Qnaqn3RGiFM',
  usdc_mint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
  marginfi_group: '4qp6Fx6tnZkY5Wropq9wUYgtFxXKwE6viZxFHg3rdAG8',
  marginfi_account: 'C8JLFVMuSFFFmDX2AEyMmP6zRXtXwJgptHeBUrnj4zLE',
  marginfi_bank: '2s37akK2eyBbp8DZgCm7RtsaEz8eJP3Nxd4urLHQv7yB',
  marginfi_liquidity_vault: '7jaiZR5Sk8hdYN9MxTpczTcwbWpb5WEoxSANuUwveuat',
  marginfi_liquidity_vault_auth: '3uxNepDbmkDNq6JhRja5Z8QwbTrfmkKP8AKZV5chYDGG',
  marginfi_oracle: 'Dpw1EAVrSB1ibxiDQyTAW6Zip3J4Btk2x4SgApQCeFbX',
};

for (const dir of ['accounts/known', 'accounts/program', 'transactions', 'replay_accounts', 'metadata']) {
  fs.mkdirSync(path.join(out, dir), { recursive: true });
}

function safeJson(value) {
  return JSON.stringify(value, (_, v) => typeof v === 'bigint' ? v.toString() : v, 2);
}
function write(rel, value) {
  fs.writeFileSync(path.join(out, rel), typeof value === 'string' ? value : safeJson(value));
}
function append(rel, value) {
  fs.appendFileSync(path.join(out, rel), `${value}\n`);
}
function encodeAccount(pubkey, info) {
  if (!info) return null;
  return {
    pubkey: pubkey.toBase58(),
    account: {
      lamports: info.lamports,
      data: [Buffer.from(info.data).toString('base64'), 'base64'],
      owner: info.owner.toBase58(),
      executable: info.executable,
      rentEpoch: info.rentEpoch,
      space: info.data.length,
    },
  };
}
async function sleep(ms) {
  await new Promise(resolve => setTimeout(resolve, ms));
}
async function retry(label, fn, attempts = 6) {
  let last;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (error) {
      last = error;
      console.error(label, 'attempt', i + 1, String(error));
      await sleep(800 * (i + 1));
    }
  }
  throw last;
}

write('metadata/addresses.json', addresses);
write('metadata/rpc.json', { rpc, capturedAt: new Date().toISOString() });

for (const [name, value] of Object.entries(addresses)) {
  const pubkey = new PublicKey(value);
  const info = await retry(`account ${name}`, () => connection.getAccountInfo(pubkey, 'confirmed'));
  write(`accounts/known/${name}.json`, encodeAccount(pubkey, info));
}

try {
  const rows = await retry('getProgramAccounts', () => connection.getProgramAccounts(PROGRAM, { commitment: 'confirmed' }), 3);
  const index = [];
  for (const row of rows) {
    write(`accounts/program/${row.pubkey.toBase58()}.json`, encodeAccount(row.pubkey, row.account));
    index.push({ pubkey: row.pubkey.toBase58(), size: row.account.data.length, lamports: row.account.lamports });
  }
  write('accounts/program/index.json', index);
} catch (error) {
  write('accounts/program/ERROR.txt', String(error));
}

try {
  const wallet = {
    publicKey: Keypair.generate().publicKey,
    signTransaction: async () => { throw new Error('read-only wallet'); },
    signAllTransactions: async () => { throw new Error('read-only wallet'); },
  };
  const provider = new AnchorProvider(connection, wallet, { commitment: 'confirmed' });
  const idl = await Program.fetchIdl(PROGRAM, provider);
  write('metadata/bankineco-idl.json', idl);
} catch (error) {
  write('metadata/bankineco-idl-error.txt', String(error));
}

const targets = [
  PROGRAM,
  ...Object.entries(addresses)
    .filter(([name]) => !name.endsWith('_program'))
    .map(([, value]) => new PublicKey(value)),
];
const signatureMap = new Map();
for (const target of targets) {
  let before;
  for (let page = 0; page < 2; page++) {
    const options = { limit: 1000 };
    if (before) options.before = before;
    let rows;
    try {
      rows = await retry(
        `signatures ${target.toBase58()}`,
        () => connection.getSignaturesForAddress(target, options, 'confirmed'),
        4,
      );
    } catch (error) {
      append('metadata/signature-errors.txt', `${target.toBase58()}: ${error}`);
      break;
    }
    for (const row of rows) signatureMap.set(row.signature, row);
    if (rows.length < 1000) break;
    before = rows.at(-1).signature;
    await sleep(250);
  }
}
const signatures = [...signatureMap.values()].sort((a, b) => (b.slot ?? 0) - (a.slot ?? 0));
write('metadata/signatures.json', signatures);

const candidates = signatures.filter(row => row.err == null).slice(0, 300);
const selected = [];
for (let i = 0; i < candidates.length; i += 20) {
  const chunk = candidates.slice(i, i + 20);
  let txs;
  try {
    txs = await retry(
      `transactions ${i}`,
      () => connection.getTransactions(chunk.map(row => row.signature), {
        commitment: 'confirmed',
        maxSupportedTransactionVersion: 0,
      }),
      5,
    );
  } catch (error) {
    append('metadata/transaction-errors.txt', `${i}: ${error}`);
    continue;
  }
  for (let j = 0; j < txs.length; j++) {
    const tx = txs[j];
    if (!tx || tx.meta?.err) continue;
    const staticKeys = tx.transaction.message.staticAccountKeys?.map(key => key.toBase58()) ?? [];
    const loadedWritable = tx.meta?.loadedAddresses?.writable?.map(key => key.toBase58()) ?? [];
    const loadedReadonly = tx.meta?.loadedAddresses?.readonly?.map(key => key.toBase58()) ?? [];
    const keys = [...staticKeys, ...loadedWritable, ...loadedReadonly];
    if (!keys.includes(PROGRAM.toBase58())) continue;
    const signature = chunk[j].signature;
    write(`transactions/${signature}.json`, tx);
    selected.push({ signature, slot: tx.slot, blockTime: tx.blockTime, keys });
  }
  await sleep(250);
}
write('transactions/index.json', selected);

const replayKeys = new Set();
for (const row of selected.slice(0, 100)) {
  for (const key of row.keys) replayKeys.add(key);
}
const replayList = [...replayKeys];
const replayIndex = [];
for (let i = 0; i < replayList.length; i += 100) {
  const pubkeys = replayList.slice(i, i + 100).map(value => new PublicKey(value));
  const infos = await retry(`replay accounts ${i}`, () => connection.getMultipleAccountsInfo(pubkeys, 'confirmed'), 5);
  for (let j = 0; j < pubkeys.length; j++) {
    const encoded = encodeAccount(pubkeys[j], infos[j]);
    if (!encoded) continue;
    write(`replay_accounts/${pubkeys[j].toBase58()}.json`, encoded);
    replayIndex.push({
      pubkey: pubkeys[j].toBase58(),
      owner: encoded.account.owner,
      executable: encoded.account.executable,
      size: encoded.account.space,
    });
  }
  await sleep(200);
}
write('replay_accounts/index.json', replayIndex);

for (const key of ['usd_star_mint', 'usdc_mint']) {
  const pubkey = new PublicKey(addresses[key]);
  try {
    const supply = await retry(`supply ${key}`, () => connection.getTokenSupply(pubkey, 'confirmed'));
    const largest = await retry(`largest ${key}`, () => connection.getTokenLargestAccounts(pubkey, 'confirmed'));
    write(`metadata/${key}-token.json`, { supply, largest });
  } catch (error) {
    write(`metadata/${key}-token-error.txt`, String(error));
  }
}

console.log(safeJson({
  programAccounts: fs.existsSync(path.join(out, 'accounts/program/index.json')),
  signatures: signatures.length,
  transactions: selected.length,
  replayAccounts: replayIndex.length,
}));

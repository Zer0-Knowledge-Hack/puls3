// Reference run for spike #164: the official x402 client pays one call, so a
// failure can be told apart as TIA's or the Dart client's. Testnet only.
//
//   npm ci && node pay.mjs <secret-key-file> <url>
import { readFileSync } from "node:fs";
import { wrapFetchWithPayment, x402Client, decodePaymentResponseHeader } from "@x402/fetch";
import { ExactStellarScheme } from "@x402/stellar/exact/client";
import { createEd25519Signer } from "@x402/stellar";

const [secretFile, url] = process.argv.slice(2);
if (!secretFile || !url) {
  console.error("usage: node pay.mjs <secret-key-file> <url>");
  process.exit(64);
}

const signer = createEd25519Signer(readFileSync(secretFile, "utf8").trim(), "stellar:testnet");
const client = new x402Client().register("stellar:testnet", new ExactStellarScheme(signer));
const pay = wrapFetchWithPayment(fetch, client);

console.log(`payer   ${signer.address}`);
const response = await pay(url);
console.log(`status  ${response.status}`);
const receipt = response.headers.get("PAYMENT-RESPONSE");
if (receipt) {
  const settled = decodePaymentResponseHeader(receipt);
  console.log(`settled ${settled.success} tx ${settled.transaction}`);
  if (settled.transaction) {
    console.log(`explorer https://stellar.expert/explorer/testnet/tx/${settled.transaction}`);
  }
}
console.log(await response.text());
process.exit(response.status === 200 ? 0 : 1);

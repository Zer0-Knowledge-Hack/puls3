// v6.0.1 is published as a CommonJS/UMD bundle. esm.sh exposes its API object
// as the default export rather than synthesizing named ESM exports.
import freighterApi from 'https://esm.sh/@stellar/freighter-api@6.0.1?bundle';

const { isConnected, requestAccess, getAddress, getNetworkDetails, signTransaction, signAuthEntry } = freighterApi;

const checked = (result) => { if (result?.error) throw new Error(result.error.message ?? String(result.error)); return result; };
const session = async () => {
  const account = checked(await getAddress());
  const network = checked(await getNetworkDetails());
  return JSON.stringify({ address: account.address, networkPassphrase: network.networkPassphrase });
};
window.puls3FreighterConnect = async () => {
  const connected = checked(await isConnected());
  if (!connected.isConnected) throw new Error('Freighter is not installed or unavailable');
  checked(await requestAccess());
  return session();
};
window.puls3FreighterCurrentSession = session;
const requireSession = async (expectedNetwork, expectedAddress) => {
  const currentNetwork = checked(await getNetworkDetails());
  const currentAccount = checked(await getAddress());
  if (currentNetwork.networkPassphrase !== expectedNetwork) throw new Error('wrong_network: Freighter network changed');
  if (currentAccount.address !== expectedAddress) throw new Error('account_changed: Freighter account changed');
};
window.puls3FreighterSignTransaction = async (xdr, networkPassphrase, address) => {
  await requireSession(networkPassphrase, address);
  return checked(await signTransaction(xdr, { networkPassphrase, address })).signedTxXdr;
};
// Freighter's signAuthEntry signs a HashIdPreimage (ENVELOPE_TYPE_SOROBAN_AUTHORIZATION, or _WITH_ADDRESS for ADDRESS_V2)
// and answers with the raw ed25519 signature over sha256(preimage) in `signedAuthEntry`.
// freighter-api forwards the extension's postMessage payload unchanged, so the runtime
// shape is not pinned: accept a base64 string, Uint8Array/ArrayBuffer (structured-cloned
// Buffer), or a JSON-serialized Node Buffer, and always hand Dart base64.
const bytesToBase64 = (bytes) => {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
};
const signatureToBase64 = (value) => {
  if (typeof value === 'string') return value;
  if (value instanceof Uint8Array) return bytesToBase64(value);
  if (value instanceof ArrayBuffer) return bytesToBase64(new Uint8Array(value));
  if (ArrayBuffer.isView(value)) return bytesToBase64(new Uint8Array(value.buffer, value.byteOffset, value.byteLength));
  if (value?.type === 'Buffer' && Array.isArray(value.data)) return bytesToBase64(Uint8Array.from(value.data));
  throw new Error('Freighter returned an unsupported auth-entry signature shape');
};
window.puls3FreighterSignAuthEntryPreimage = async (preimageXdr, networkPassphrase, address) => {
  await requireSession(networkPassphrase, address);
  const result = checked(await signAuthEntry(preimageXdr, { networkPassphrase, address }));
  if (!result.signedAuthEntry) throw new Error('Freighter returned no auth-entry signature');
  if (result.signerAddress && result.signerAddress !== address) throw new Error('account_changed: Freighter signed with another account');
  return JSON.stringify({ signature: signatureToBase64(result.signedAuthEntry), signerAddress: result.signerAddress || null });
};

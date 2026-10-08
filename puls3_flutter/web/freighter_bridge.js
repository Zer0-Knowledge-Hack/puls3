// Freighter bridge for the Flutter app (#25), from the #70 spike.
//
// @stellar/freighter-api v6.0.1 is loaded from a pinned CDN URL, as in the
// spike. Production must bundle it locally and enforce a CSP.
// v6.0.1 is a CommonJS/UMD bundle: esm.sh exposes its API as the default export.
import freighterApi from 'https://esm.sh/@stellar/freighter-api@6.0.1?bundle';

const { isConnected, requestAccess, getAddress, getNetworkDetails, signTransaction, signAuthEntry } = freighterApi;

// Every failure leaves here as "<code>: <message>" so Dart can type it.
const fail = (code, message) => { throw new Error(`${code}: ${message}`); };
const checked = (result, code) => {
  if (result?.error) fail(code, result.error.message ?? String(result.error));
  return result;
};

const session = async () => {
  const account = checked(await getAddress(), 'unavailable');
  const network = checked(await getNetworkDetails(), 'unavailable');
  if (!account.address) fail('unavailable', 'Freighter has no connected account');
  return JSON.stringify({ address: account.address, networkPassphrase: network.networkPassphrase });
};

window.puls3FreighterConnect = async () => {
  let connected;
  try {
    connected = await isConnected();
  } catch (e) {
    fail('not_installed', 'Freighter is not installed');
  }
  if (!connected?.isConnected) fail('not_installed', 'Freighter is not installed');
  checked(await requestAccess(), 'rejected');
  return session();
};

window.puls3FreighterCurrentSession = session;

const requireSession = async (expectedNetwork, expectedAddress) => {
  const network = checked(await getNetworkDetails(), 'unavailable');
  const account = checked(await getAddress(), 'unavailable');
  if (network.networkPassphrase !== expectedNetwork) fail('wrong_network', 'Freighter network changed');
  if (account.address !== expectedAddress) fail('account_changed', 'Freighter account changed');
};

window.puls3FreighterSignTransaction = async (xdr, networkPassphrase, address) => {
  await requireSession(networkPassphrase, address);
  return checked(await signTransaction(xdr, { networkPassphrase, address }), 'rejected').signedTxXdr;
};

// Freighter's signAuthEntry signs a HashIdPreimage and answers with the raw
// ed25519 signature over sha256(preimage). Its runtime shape is not pinned:
// accept base64, Uint8Array/ArrayBuffer or a serialized Buffer; return base64.
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
  fail('invalid', 'Freighter returned an unsupported auth-entry signature shape');
};

window.puls3FreighterSignAuthEntryPreimage = async (preimageXdr, networkPassphrase, address) => {
  await requireSession(networkPassphrase, address);
  const result = checked(await signAuthEntry(preimageXdr, { networkPassphrase, address }), 'rejected');
  if (!result.signedAuthEntry) fail('rejected', 'Freighter returned no auth-entry signature');
  if (result.signerAddress && result.signerAddress !== address) fail('account_changed', 'Freighter signed with another account');
  return JSON.stringify({ signature: signatureToBase64(result.signedAuthEntry), signerAddress: result.signerAddress || null });
};

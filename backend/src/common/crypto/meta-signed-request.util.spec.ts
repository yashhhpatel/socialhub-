import { createHmac } from 'crypto';

import { parseMetaSignedRequest } from './meta-signed-request.util';

const APP_SECRET = 'test-app-secret';

function base64Url(buf: Buffer): string {
  return buf
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/** Builds a valid signed_request the way Meta does, for the given payload. */
function sign(
  payload: Record<string, unknown>,
  secret = APP_SECRET,
): string {
  const encodedPayload = base64Url(Buffer.from(JSON.stringify(payload)));
  const sig = createHmac('sha256', secret).update(encodedPayload).digest();
  return `${base64Url(sig)}.${encodedPayload}`;
}

describe('parseMetaSignedRequest', () => {
  it('parses and returns the payload of a correctly-signed request', () => {
    const result = parseMetaSignedRequest(
      sign({ algorithm: 'HMAC-SHA256', user_id: 'meta_123', issued_at: 1 }),
      APP_SECRET,
    );
    expect(result).not.toBeNull();
    expect(result?.user_id).toBe('meta_123');
  });

  it('rejects a request signed with a different secret (forgery)', () => {
    const forged = sign(
      { algorithm: 'HMAC-SHA256', user_id: 'attacker' },
      'wrong-secret',
    );
    expect(parseMetaSignedRequest(forged, APP_SECRET)).toBeNull();
  });

  it('rejects a payload tampered with after signing', () => {
    const valid = sign({ algorithm: 'HMAC-SHA256', user_id: 'meta_123' });
    const [sig] = valid.split('.', 2);
    const tamperedPayload = base64Url(
      Buffer.from(JSON.stringify({ algorithm: 'HMAC-SHA256', user_id: 'evil' })),
    );
    expect(
      parseMetaSignedRequest(`${sig}.${tamperedPayload}`, APP_SECRET),
    ).toBeNull();
  });

  it('rejects the wrong algorithm', () => {
    expect(
      parseMetaSignedRequest(
        sign({ algorithm: 'PLAINTEXT', user_id: 'meta_123' }),
        APP_SECRET,
      ),
    ).toBeNull();
  });

  it('rejects a payload missing user_id', () => {
    expect(
      parseMetaSignedRequest(sign({ algorithm: 'HMAC-SHA256' }), APP_SECRET),
    ).toBeNull();
  });

  it('rejects malformed input (no dot, empty, undefined)', () => {
    expect(parseMetaSignedRequest('not-a-signed-request', APP_SECRET)).toBeNull();
    expect(parseMetaSignedRequest('', APP_SECRET)).toBeNull();
    expect(parseMetaSignedRequest(undefined, APP_SECRET)).toBeNull();
    expect(parseMetaSignedRequest('.', APP_SECRET)).toBeNull();
  });
});

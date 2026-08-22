import { createHmac } from 'crypto';

import { verifyMetaWebhookSignature } from './meta-webhook-signature.util';

const SECRET = 'app-secret';

function sign(body: string, secret = SECRET): string {
  return 'sha256=' + createHmac('sha256', secret).update(body).digest('hex');
}

describe('verifyMetaWebhookSignature', () => {
  const body = JSON.stringify({ object: 'instagram', entry: [] });

  it('accepts a correct signature over the raw body', () => {
    expect(verifyMetaWebhookSignature(body, sign(body), SECRET)).toBe(true);
  });

  it('accepts a Buffer body identical to the signed bytes', () => {
    expect(
      verifyMetaWebhookSignature(Buffer.from(body, 'utf8'), sign(body), SECRET),
    ).toBe(true);
  });

  it('rejects a signature made with a different secret', () => {
    expect(verifyMetaWebhookSignature(body, sign(body, 'other'), SECRET)).toBe(false);
  });

  it('rejects a tampered body', () => {
    expect(verifyMetaWebhookSignature(body + ' ', sign(body), SECRET)).toBe(false);
  });

  it('rejects a header without the sha256= prefix', () => {
    const bare = createHmac('sha256', SECRET).update(body).digest('hex');
    expect(verifyMetaWebhookSignature(body, bare, SECRET)).toBe(false);
  });

  it('rejects missing body, header, or secret', () => {
    expect(verifyMetaWebhookSignature(undefined, sign(body), SECRET)).toBe(false);
    expect(verifyMetaWebhookSignature(body, undefined, SECRET)).toBe(false);
    expect(verifyMetaWebhookSignature(body, sign(body), undefined)).toBe(false);
  });

  it('rejects a malformed (non-hex / wrong-length) signature without throwing', () => {
    expect(verifyMetaWebhookSignature(body, 'sha256=zzzz', SECRET)).toBe(false);
  });
});

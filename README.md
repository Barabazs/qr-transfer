# QR Transfer

File transfer by light: a single self-contained HTML page. One screen blinks QR codes,
the other device's camera reads them — no network, no server. Built to be hosted on
Ethereum Swarm.

- **Send**: text becomes plain base64; any file becomes a `data:<mime>;base64,...` URI.
  Payloads that fit in one QR (≤ 2,331 bytes, EC level M) are emitted as a plain QR any
  scanner app can read. Bigger payloads stream as **fountain-coded** frames
  (`QRF|<transferId>|<k>|<len>|<seed>|<b64 xor-block>`, EC level L, fixed QR version per
  transfer): first a systematic pass (each of the `k` chunks once, in order — a clean
  first pass completes immediately), then an endless deterministic stream of repair
  frames, each the XOR of a pseudo-random chunk set (robust-soliton degree, seed in the
  frame). Any repair frame can patch whatever the receiver is missing, so a missed frame
  never costs another full loop. Frames are generated live — no pre-render stall on
  large payloads.
- **Receive**: live camera scanning — adaptive rate (scans as fast as decode completes,
  up to ~40 Hz) with the native `BarcodeDetector` API where available (Android Chrome)
  and jsQR everywhere else — or dropped/uploaded QR images, fed through a peeling
  (belief-propagation) fountain decoder. Output is the encoded string verbatim, plus a
  decode panel (image preview / text / download). Filenames are not carried — downloads
  get a name like `qr-transfer-<id>.<ext>`, with the extension guessed from the MIME
  type.

## Usage

Open `index.html` — from disk, `python3 -m http.server`, or a Swarm gateway. The camera
requires a secure context: HTTPS gateways and `localhost` work, and `file://` works in
most desktop browsers; plain `http://<lan-ip>` does not (use the image-upload path
there).

Practical pacing at the defaults (500 B chunks, 8 fps): a 50 KB file is ~137 chunks ≈
17 s for the systematic pass, then a handful of seconds of repair frames for whatever
was missed — total is roughly one pass plus 10–30 %, regardless of *which* frames were
dropped. The page warns above 100 KB encoded (base64 is ≈ ⅓ larger than the source
file), and again above 500 KB. Transfers are hard-capped at 9,999 chunks — the QRF
frame format's limit (≈ 4.77 MB encoded at the default 500 B frame size). The old
sequential `QRX` format is gone (hard cutover); previously exported `QRX` frame images
are no longer readable.

Self-test (full in-memory optical round trip, no camera needed):

```
index.html?selftest
```

Sender-side **Export frames** downloads frame PNGs (20 per click) that can be dropped
straight into the Receive tab — a camera-free end-to-end check.

## FAQ

**Does my data leave the device?** No. The CSP meta tag (`default-src 'none'`) blocks
every network request, and nothing is written to disk. Reload the page and it's all
gone.

**How much can I send?** One QR code holds up to 2,331 bytes. Past that, payloads
stream in up to 9,999 chunks: roughly 1.9, 4.77 or 7.6 MB encoded at 200, 500 or
800-byte frames. Base64 adds a third on top, so a 75 KB file already trips the 100 KB
warning. Small transfers stay pleasant; multi-hundred-KB ones mean minutes of holding
the phone still.

**Can a normal scanner app read the codes?** The small single-code payloads, yes.
Streamed QRF frames mean nothing to other scanners — the receiving end has to be this
page.

**What if the receiver misses frames?** Nothing to do. Repair frames keep coming and
any one of them can fill any gap, so a dropped frame costs seconds, not another lap
through the whole sequence.

**Is the transfer verified?** Partly. Each frame carries QR error correction and the
result has to parse cleanly (strict UTF-8, valid base64). That catches most damage, but
it is not a checksum. Compare anything important against the original before deleting
it.

**Are filenames kept?** No — just the bytes and the MIME type. Downloads come out as
`qr-transfer-<id>.<ext>`.

**The camera won't start?** It needs permission and a secure page (HTTPS or localhost).
If it stays dead, drop QR images into the Receive tab instead; screenshots decode
better than photos anyway.

## Deploy to Ethereum Swarm

```bash
swarm-cli upload index.html --stamp <batch-id>
```

Needs a Bee node with a funded postage batch — or upload without a node via
[Beeport](https://beeport.ethswarm.org/). One file, one reference. The page makes zero
external requests (enforced by its CSP meta tag), so it works from any gateway and
offline.

## Vendored libraries

Both libraries are inlined **verbatim** into `index.html` so the inline blocks can be
diffed against the npm tarballs to audit the pinned artifact.

| Library | File in tarball | Size | sha256 |
|---|---|---|---|
| `qrcode-generator@2.0.4` (MIT, Kazuhiko Arase) | `package/dist/qrcode.js` | 56,694 B | `79ec86f82856005b1c887905cfccfcfbec3821ca61c7fd5a952faa5f778f791c` |
| `jsqr@1.4.0` (MIT, Cosmo Wolfe) | `package/dist/jsQR.js` | 256,885 B | `bc40c8a15196236b2314db0856f72ca0b49980cd5413b8c852a7349f5fee0859` |

Re-vendoring:

```bash
curl -sL https://registry.npmjs.org/qrcode-generator/-/qrcode-generator-2.0.4.tgz | tar xzf - -O package/dist/qrcode.js > qrcode.js
curl -sL https://registry.npmjs.org/jsqr/-/jsqr-1.4.0.tgz                        | tar xzf - -O package/dist/jsQR.js   > jsQR.js
sha256sum qrcode.js jsQR.js          # must match the table above
grep -c '</script\|<!--' qrcode.js jsQR.js   # must print 0 for both — required for safe inlining
```

Replace the marked `VENDORED` script blocks in `index.html` with the new contents and
update the banners, table, and hashes.

## Disclaimer

Use at your own risk, with no warranty of any kind. Nothing guards a finished transfer
beyond QR error correction and a clean parse, so whether the copy is good is for you to
decide: keep the original until you've checked. Nothing is stored, either. A reload or
reset throws away all progress and received data.

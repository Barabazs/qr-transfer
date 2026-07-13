# qr-transfer

Single self-contained HTML page (`index.html`) that moves data between screens
via QR codes. Zero network requests (enforced by CSP meta tag), deployable as
one file to IPFS. See `README.md` for the protocol and usage.

## Hard constraints

- **One file, no build step.** All CSS/JS stays inline in `index.html`. Do not
  split it, add a bundler, or reference external resources.
- **Never edit the two `VENDORED` script blocks** (banners at the top of each:
  `qrcode-generator@2.0.4` and `jsqr@1.4.0`). They must stay byte-identical to
  the pinned npm artifacts — `verify.sh` enforces their sha256. Re-vendoring
  procedure is in `README.md`.
- The app code is the last `<script>` block (sections §1–§9). Edit only there
  and in the HTML/CSS before the first vendored block.

## Verification

- `./verify.sh` — vendored-block integrity + headless self-test (1–3 min).
  Run it after ANY change to `index.html`; it must print `PASS: all checks`.
- `SKIP_SELFTEST=1 ./verify.sh` — fast hash-only check.
- Manual: open `index.html?selftest` in a browser.
- Camera paths cannot be tested headless; changes to §6 (camera) need a manual
  check on a real device.

# Legacy Static Images Review

Date: 2026-03-20

## Scope
Review of `root/static/images/*` as a potential cleanup target.

## Files reviewed
- `btn_120x50_built.png`
- `btn_120x50_built_shadow.png`
- `btn_120x50_powered.png`
- `btn_120x50_powered_shadow.png`
- `btn_88x31_built.png`
- `btn_88x31_built_shadow.png`
- `btn_88x31_powered.png`
- `btn_88x31_powered_shadow.png`
- `catalyst_logo.png`

## Evidence gathered
- Repo-wide searches found no current in-repo references to these image names or `/static/images/*` paths in app templates, code, CSS, scripts, or tests.
- Real browser checks on `https://bracket.mso.mt/` found no image tags, CSS background images, DOM refs, or browser requests for `/static/images/*` on these pages:
  - `/login`
  - `/`
  - `/all`
  - `/account`
  - `/region/view/1/63`
  - `/final4/make/63`
  - `/final4/view/63`
- `catalyst_logo.png` remains directly reachable by URL, which means these assets may still exist as public compatibility artifacts even if the app no longer renders them.
- Git history indicates these assets date back to the 2010 general-release era.

## Conclusion
These assets are strong **deprecation candidates** but not yet strong **deletion candidates**.

We have strong evidence of no current internal app usage, but we do not yet have strong evidence that no external or direct-URL usage remains.

## Recommended next step
1. Treat these files as legacy/public compatibility assets for now.
2. Check production access logs for `/static/images/*` over a meaningful window.
3. Only open a deletion PR once external usage is ruled out or accepted as safe to break.

## Rule of thumb
Old and boring is fine.
Old, boring, and publicly reachable is where cleanup gets sneaky.

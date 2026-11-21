# Ingress end-to-end test

Opens the admin UI in Chromium inside a mock of Home Assistant's ingress iframe and clicks through
it: first-run setup, every menu entry, reload, logout and login. Every request that does not stay
below the ingress path counts as a failure, as does any error in the browser console.

Run it after every NPMplus update, because the UI bundle is patched at build time and the browser
shim depends on how the UI loads its resources:

```bash
.github/dev/ingress-e2e/run.sh
```

It needs Docker, Node.js with Playwright and a root shell. It is not part of the pipeline.

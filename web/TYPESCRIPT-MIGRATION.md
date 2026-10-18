# WOA Arcane Realm TypeScript migration

The browser game is migrating in stages to preserve existing gameplay while code is split into typed modules.

## Build

Use Node.js 20 or newer:

```sh
npm install
npm run build
```

`npm run typecheck` checks the TypeScript source with strict settings. `npm run build` generates `web/runtime/arcane-art.js` from `web/src/arcane-art.ts` using esbuild.

The first typed module owns loading the art ZIP, the `woaArtReady` compatibility promise, portrait previews, familiar/enemy/Mathias/spell crops, and concept-art gallery sources. The existing Phaser scene and UI remain compatible while they are migrated in subsequent steps. The generated bundle is committed so Nginx/Railway does not need Node during image build. After editing TypeScript, run `npm run build` and commit both source and generated output.

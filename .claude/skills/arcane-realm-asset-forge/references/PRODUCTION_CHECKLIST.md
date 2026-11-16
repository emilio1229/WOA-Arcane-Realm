# Asset production and review checklist

## Brief
- [ ] Stable ID checked against existing manifest
- [ ] Category, use case, gameplay context, and owner recorded
- [ ] Camera distance, screen footprint, platform, and target size known
- [ ] Palette, silhouette, perspective, materials, and lighting specified
- [ ] Dimensions, aspect ratio, alpha, pivot, and animation requirements specified
- [ ] Performance/fallback requirements considered
- [ ] Source and license/provenance recorded

## Visual review
- [ ] Matches Arcane Realm art direction
- [ ] Clear silhouette at actual gameplay scale
- [ ] Consistent perspective, proportions, and scale
- [ ] Clean edges, alpha, and no generation artifacts
- [ ] Lighting/materials read clearly without excessive glow
- [ ] UI/icons remain legible at actual display size
- [ ] VFX do not hide enemies, telegraphs, or interactions
- [ ] Animation frames align and loop cleanly where intended

## Technical review
- [ ] Format and loader are supported by the current project
- [ ] Dimensions and metadata match the actual file
- [ ] Manifest ID is unique and paths resolve
- [ ] Sprite-sheet cells, frame count, rate, and pivots are valid
- [ ] No external script/reference content in inline SVG
- [ ] No missing references or console errors
- [ ] Runtime size/performance is reasonable
- [ ] Source art retained; derivative/version relationship recorded

## Integration and tests
- [ ] Asset loaded in a real test scene
- [ ] Correct scale, depth sorting, origin, transparency, and animation
- [ ] Desktop layout/input checked
- [ ] Mobile viewport/touch target checked where relevant
- [ ] Existing gameplay regression checked
- [ ] `npm run assets:validate` passed
- [ ] Relevant `npm run typecheck`, `npm run build`, and browser tests passed

## Final status
Use `concept`, `in-production`, `needs-review`, `integrated`, or `validated`. Only use `validated` when the relevant visual and technical checks were actually completed. Record any checks not performed as explicit limitations.

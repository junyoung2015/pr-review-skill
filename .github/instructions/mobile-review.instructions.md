---
applyTo: "apps/mobile/**/*.ts,apps/mobile/**/*.tsx"
---

For `apps/mobile` reviews:

- Prioritize auth correctness, bridge/schema compatibility, and platform-specific regressions over formatting or naming nits.
- If native auth payloads change, verify downstream TypeScript types and shared bridge schema definitions were updated consistently.
- Call out race conditions, missing guards, or incorrect assumptions around async sign-in, credential exchange, or app config values.
- Be careful with Expo / app config comments: only flag env or config changes when they can actually break build, runtime, or store-integrated login flows.
- Test comments should focus on real coverage quality. Flag commented-out or placeholder tests when they add maintenance noise or hide an unfinished path.

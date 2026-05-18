# GitHub Reference Report

Research date: 2026-05-18. Only permissive-license candidates are recommended for learning or selective adaptation. Do not copy app-specific assets, sample secrets, or product-specific branding.

| Repo | URL | Stars | Last Update | License | Stack | Reusable Parts | Do Not Reuse | Fit |
| --- | --- | ---: | --- | --- | --- | --- | --- | ---: |
| momentous-developments/flutter-starter-app | https://github.com/momentous-developments/flutter-starter-app | 19 | Search result crawled 2026 | MIT | Flutter, Riverpod, GoRouter, Material 3, clean architecture | Flutter foldering, routing, Riverpod app shell | Product screens/copy; use only architecture patterns | 7 |
| edemekong/city-cab | https://github.com/edemekong/city-cab | 180 | Search result crawled 2026 | MIT | Flutter taxi app, Firebase, maps, Provider/BLoC | Uber-like map and booking flow concepts | Firebase-specific backend approach and app identity | 7 |
| radikris/booking_calendar | https://github.com/radikris/booking_calendar | 71 | Search result crawled 2026 | MIT | Flutter booking calendar package, Firebase example | Conflict visualization, time-slot UI ideas | Firebase data model as-is; this MVP uses PostGIS/NestJS | 5 |
| michu2k/nestjs-booking-system | https://github.com/michu2k/nestjs-booking-system | Not verified | Search result crawled 2026 | MIT | NestJS 11, Prisma, PostgreSQL, Docker | Simple booking module shape, Prisma/Nest wiring | Domain model directly; it is not realtime matching | 6 |
| kaungkhantdev/nestjs-api-starter | https://github.com/kaungkhantdev/nestjs-api-starter | 17 | GitHub page opened 2026, 84 commits | MIT | NestJS 11, Prisma, PostgreSQL, JWT, RBAC, S3, tests | Auth/RBAC, repository boundaries, S3 upload patterns | Role names/domain model directly | 7 |
| arhamkhnz/next-shadcn-admin-dashboard | https://github.com/arhamkhnz/next-shadcn-admin-dashboard | 2.3k | Active/frequently updated per README | MIT | Next.js 16, TypeScript, Tailwind v4, shadcn/ui, TanStack Table, Zod | Admin layout, RBAC UI ideas, table/chart components | Theme presets/branding wholesale | 8 |
| Qualiora/shadboard | https://github.com/Qualiora/shadboard | 651 | Latest release shown Jun 7, 2025 | MIT | Next.js 15, React 19, Tailwind 4, shadcn/ui, NextAuth, Recharts, TanStack Table | Dashboard layout, auth page structure, calendar/table/chart patterns | Demo content and visual identity | 7 |
| NaveenDA/shadcn-nextjs-dashboard | https://github.com/naveenda/shadcn-nextjs-dashboard | 99 | GitHub page crawled 2026 | MIT | Next.js 14, TypeScript, Tailwind, shadcn/ui | Lightweight admin starter structure | Treat as UI reference only; less complete for operations | 6 |
| taskforcesh/bullmq | https://github.com/taskforcesh/bullmq | 7.8k | Package index showed latest published Oct 31, 2025 | MIT | TypeScript, Redis queues | Queue semantics, repeatable jobs, retry patterns | Internal implementation code beyond normal library usage | 8 |
| nestjs/nest | https://github.com/nestjs/nest | Not verified here | Active framework | MIT | NestJS, TypeScript, Socket.IO adapter support | Official module/gateway patterns | N/A; consume as framework dependency | 8 |

## Recommendation

Use repository code only after re-checking license files directly at implementation time. For this MVP, the safest path is original code using public framework APIs, with these repos as pattern references rather than code sources.

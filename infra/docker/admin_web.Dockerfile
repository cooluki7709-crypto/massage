FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/admin_web/package.json apps/admin_web/package.json
COPY packages/shared-types/package.json packages/shared-types/package.json
RUN npm ci

COPY . .
ENV ADMIN_API_BASE_URL=http://api:3000/api
RUN npm run build --workspace @massage-vn/admin-web

FROM node:22-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

COPY --from=build /app/package*.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/apps/admin_web ./apps/admin_web
COPY --from=build /app/packages ./packages

EXPOSE 3000
CMD ["npm", "run", "start", "--workspace", "@massage-vn/admin-web"]

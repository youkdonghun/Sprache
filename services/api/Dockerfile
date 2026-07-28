FROM node:24-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
COPY services/api/package.json services/api/package.json
RUN npm ci --workspace @sprache/api

COPY services/api services/api
RUN npm --workspace @sprache/api run prisma:generate
RUN npm --workspace @sprache/api run build

FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

COPY package.json package-lock.json ./
COPY services/api/package.json services/api/package.json
RUN npm ci --omit=dev --workspace @sprache/api

COPY --from=build /app/services/api/dist services/api/dist
COPY --from=build /app/node_modules/.prisma node_modules/.prisma
COPY --from=build /app/node_modules/@prisma node_modules/@prisma
COPY services/api/prisma services/api/prisma

USER node
EXPOSE 3000
CMD ["npm", "--workspace", "@sprache/api", "run", "start:prod"]

ARG NODE_VERSION=22.19.0
ARG PNPM_VERSION=10.28.2

FROM node:${NODE_VERSION}-alpine AS base

WORKDIR /usr/src/app

RUN --mount=type=cache,target=/root/.npm \
    npm install -g pnpm@${PNPM_VERSION}

FROM base AS deps

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --prod --frozen-lockfile --no-verify-store-integrity

FROM deps AS build

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --no-frozen-lockfile --no-verify-store-integrity

COPY . .
RUN pnpm run build

FROM base AS final

ENV NODE_ENV=production


USER root
RUN chown node:node /usr/src/app

USER node

COPY --chown=node:node package.json .
COPY --chown=node:node pnpm-lock.yaml .
COPY --from=build --chown=node:node /usr/src/app/node_modules ./node_modules
COPY --from=build --chown=node:node /usr/src/app/dist ./dist

EXPOSE 4173

CMD ["node_modules/.bin/vite", "preview", "--host", "0.0.0.0", "--port", "4173"]
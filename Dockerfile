# syntax = docker/dockerfile:1

# Adjust NODE_VERSION as desired
ARG NODE_VERSION=22
FROM node:${NODE_VERSION}-slim as base

LABEL fly_launch_runtime="Node.js"

# Node.js app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV="development"

# Install pnpm
ARG PNPM_VERSION=9.12.3
RUN npm install -g pnpm@$PNPM_VERSION

# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential node-gyp pkg-config python-is-python3

# Copy package manager files first (to leverage caching)
COPY package.json pnpm-lock.yaml ./

# Install node modules
RUN pnpm install --frozen-lockfile
RUN pnpm rebuild better-sqlite3
RUN pnpm install --include=optional sharp
RUN pnpm add -D ts-node typescript @types/node
RUN pnpm add tsup

# Copy application code
COPY . .

# Copy SQLite database
COPY ./data/db.sqlite /app/data/db.sqlite

# Build the project
RUN pnpm run build

# Remove development dependencies
RUN chown -R node:node /app

USER node

# Final stage for app image
FROM base

# Copy built application
COPY --from=build /app /app

# Copy SQLite database to the final image
COPY --from=build /app/data/db.sqlite /app/data/db.sqlite

# Setup SQLite database volume
RUN mkdir -p /data && chown -R node:node /data
VOLUME /data

# Set environment variable for SQLite
ENV SQLITE_FILE="file:///data/sqlite.db"

# Default command to copy DB to volume on startup
CMD ["sh", "-c", "cp -n /app/data/db.sqlite /data/sqlite.db && pnpm start"]

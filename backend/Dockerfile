# Optional: use on Railway, Fly.io, Render (Docker), or any container host.
FROM node:20-alpine
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY index.mjs emailTemplates.mjs ./

ENV NODE_ENV=production
EXPOSE 8787
CMD ["node", "index.mjs"]

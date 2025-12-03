FROM node:20-slim
WORKDIR /usr/src/app
COPY app/package.json ./
RUN npm ci --only=production
COPY app/ ./
EXPOSE 8080
CMD ["node","index.js"]

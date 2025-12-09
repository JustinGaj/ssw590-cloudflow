FROM node:20-slim
WORKDIR /app
# Copy from root
COPY package*.json ./ 
RUN npm install --production
COPY index.js .
EXPOSE 8080
CMD ["node", "index.js"]
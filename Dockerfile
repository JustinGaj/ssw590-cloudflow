FROM node:20-slim
WORKDIR /app
# Copy package files from the root context
COPY package*.json ./ 
RUN npm install --production
# Copy your app code (index.js) from the root context
COPY index.js .
# Expose the port used by your app/tests
EXPOSE 8080
# Define the command to run the application
CMD ["npm", "start"]
# Use Node.js official image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy functions directory
COPY functions /app

# Install dependencies
RUN npm install

# Expose port
EXPOSE 3000

# Start server
CMD ["node", "index.js"]

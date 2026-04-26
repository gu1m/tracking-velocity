# Use Node.js 20 (better performance, Supabase recommended)
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy functions directory
COPY functions/ .

# Install dependencies
RUN npm ci --only=production

# Expose port
EXPOSE 3000

# Start server
CMD ["npm", "start"]

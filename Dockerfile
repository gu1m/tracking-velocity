# Use Node.js 20
FROM node:20-alpine

WORKDIR /app

COPY functions/ .

RUN npm ci --only=production

EXPOSE 3000

CMD ["npm", "start"]

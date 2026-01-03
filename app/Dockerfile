# --- Stage 1: Build Stage ---
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including TypeScript/tsc)
RUN npm install

# Copy the rest of the source code
COPY . .

# Compile TypeScript to JavaScript (creates the /dist folder)
RUN npm run build


# --- Stage 2: Runtime Stage ---
FROM node:20-alpine

# Add AWS Lambda Web Adapter
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter

WORKDIR /app

# Copy only the compiled code and package files from the builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./   
# copy package.json and package-lock.json

# Install ONLY production dependencies to keep the image small
RUN npm install --omit=dev

# Set Environment Variables
ENV PORT=3000
ENV NODE_ENV=production
# Redirect npm cache for Lambda's read-only filesystem
ENV NPM_CONFIG_CACHE=/tmp/.npm 

EXPOSE 3000

# Start the compiled JS directly
CMD ["node", "dist/server.js"]
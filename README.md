# DevOps Stage 1 Test Application

A simple Node.js application for testing automated deployment.

## Endpoints
- `/` - Main page
- `/health` - Health check endpoint

## Running Locally
```bash
npm install
npm start
```

## Running with Docker
```bash
docker build -t test-app .
docker run -p 3000:3000 test-app
```

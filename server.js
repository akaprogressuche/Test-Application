const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>DevOps Stage 1 - Success!</title>
        <style>
          body {
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            text-align: center;
          }
          .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 50px;
            border-radius: 20px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
          }
          h1 {
            font-size: 3em;
            margin: 0;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
          }
          .emoji {
            font-size: 5em;
            margin: 20px 0;
          }
          p {
            font-size: 1.2em;
            margin: 20px 0;
          }
          .info {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 10px;
            margin-top: 30px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Deployment Successful!</h1>
          <p>Your DevOps Stage 1 task is working perfectly!</p>
          <div class="info">
            <p><strong>Server Time:</strong> ${new Date().toLocaleString()}</p>
            <p><strong>Port:</strong> ${PORT}</p>
            <p><strong>Status:</strong> ✅ Running</p>
          </div>
        </div>
      </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📅 Started at: ${new Date().toLocaleString()}`);
});

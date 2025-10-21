const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
<html>
      <head>
        <title>DevOps Stage 1 - Please Display!</title>
        <style>
          body {
            font-family: 'Arial', sans-serif;
            background-color:#43e9b );
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
            padding: 50px;;
          }
          h1 {
            font-size: 3em;
            margin: 0;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
          }


          p {
            font-size: 1.2em;
            margin: 20px 0;
          }
          .info {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            margin-top: 30px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Deployment Successful!</h1>
          <p>If you see this, the automation worksy!</p>
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

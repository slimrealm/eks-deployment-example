const express = require('express');
const os = require('os');
const app = express();
const port = 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.send(`Hello from pod: ${os.hostname()}`);
});

app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
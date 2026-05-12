const { createServer } = require('http')
const { parse } = require('url')
const next = require('next')

const dev = process.env.NODE_ENV !== 'production'
const hostname = 'localhost'
const port = process.env.PORT || 3000
const app = next({ dev, hostname, port })
const handle = app.getRequestHandler()

app.prepare().then(() => {
  const httpServer = createServer(async (req, res) => {
    try {
      const parsedUrl = parse(req.url, true)
      await handle(req, res, parsedUrl)
    } catch (err) {
      console.error('Error occurred handling', req.url, err)
      res.statusCode = 500
      res.end('internal server error')
    }
  })

  // Initialize Socket.IO and attach to the SAME server
  // We require the socket index directly. 
  // Note: Since this is JS, we might need to point to the built version in production
  // but for local/Railway it should be fine if we use the right paths.
  try {
    const { getIO } = require('./src/socket/index')
    getIO(httpServer)
    console.log('[socket.io] attached to main server')
  } catch (e) {
    // If it fails (e.g. because it's TS), we might need to handle it.
    // In production Railway builds, the files are in .next or similar.
    console.warn('[socket.io] could not attach during prepare, will retry if instrumentation runs')
  }

  httpServer.listen(port, (err) => {
    if (err) throw err
    console.log(`> Ready on http://${hostname}:${port}`)
  })
})

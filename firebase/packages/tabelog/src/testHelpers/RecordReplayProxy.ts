import path from 'path'

import talkback from 'talkback/es6'
import { RecordMode } from 'talkback/options'
import TalkbackServer from 'talkback/server'
import Tape from 'talkback/tape'
import { Req } from 'talkback/types'

export { TalkbackServer, Tape }

export interface RecordReplayProxyOptions {
  targetOrigin: string
  localhostPort: number
  ignoreQueryParams?: string[]
  ignoreHeaders?: string[]
  ignoreBody?: boolean
}

export async function startRecordReplayProxy(
  options: RecordReplayProxyOptions,
): Promise<RecordReplayProxy> {
  const server = new RecordReplayProxy(options)
  await server.start()
  return server
}

// Wrapper around talkback server
export class RecordReplayProxy {
  private readonly talkbackServer: TalkbackServer
  private _isRunning = false
  private _receivedRequests: Req[] = []

  constructor(public readonly options: RecordReplayProxyOptions) {
    // Validate targetOrigin
    try {
      new URL(options.targetOrigin)
    } catch {
      throw new Error(
        `targetOrigin must consist of protocol, hostname, and port (if needed) like "http://example.com", got ${options.targetOrigin}`,
      )
    }

    // https://github.com/ijpiantanida/talkback#options
    this.talkbackServer = talkback({
      host: options.targetOrigin,
      port: options.localhostPort,
      record: process.env.CI ? RecordMode.DISABLED : RecordMode.NEW,
      debug: !!process.env.DEBUG,
      silent: !process.env.DEBUG,
      summary: true,
      ignoreQueryParams: options.ignoreQueryParams ?? [],
      ignoreHeaders: options.ignoreHeaders,
      ignoreBody: options.ignoreBody,
      tapeNameGenerator: generateTapeName,
      requestDecorator: (req: Req): Req => {
        this._receivedRequests.push(req)
        return req
      },
    })
  }

  async start() {
    if (this.isRunning) return

    await this.talkbackServer.start()
    this._isRunning = true
  }

  stop() {
    if (!this.isRunning) return

    return new Promise<void>((resolve) => {
      this.talkbackServer.close(() => {
        this._isRunning = false
        resolve()
      })
    })
  }

  get isRunning() {
    return this._isRunning
  }

  get receivedRequests(): Req[] {
    return this._receivedRequests
  }

  clearReceivedRequests() {
    this._receivedRequests = []
  }

  generateProxyURLFromRealURL(realURL: string | URL): string {
    const url = new URL(realURL)

    if (url.origin !== this.options.targetOrigin) {
      throw new Error(
        `Given real URL ${url.toString()} does not match proxy target origin ${
          this.options.targetOrigin
        }`,
      )
    }

    url.protocol = 'http:'
    url.hostname = 'localhost'
    url.port = this.options.localhostPort.toString()
    return url.toString()
  }
}

// Note that tape name is _not_ used for tape matching.
// This function is invoked only when saving tape (i.e. when a real request is performed).
function generateTapeName(tapeNumber: number, { req, res, meta }: Tape): string {
  const url = new URL(req.url, meta.host)

  const filename = [tapeNumber, req.method, url.pathname, res?.status]
    .filter((e) => e)
    .join('-')
    .toLowerCase()
    .replace(/\//g, '_')

  return path.join(url.host, filename)
}

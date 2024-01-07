import axios from 'axios'
// @ts-ignore: no type definition provided
import { parse_host as parseHost } from 'tld-extract'

export type ExpandedURL = URL & { originalURL: URL }

export async function expandURL(originalURL: URL | string): Promise<ExpandedURL> {
  if (typeof originalURL == 'string') {
    originalURL = new URL(originalURL)
  }

  const response = await axios.get(originalURL.toString(), {
    maxRedirects: 0,
    validateStatus: () => true,
  })

  const expandedURLString: string = response.headers['location']
  if (!expandedURLString) {
    return createExpandedURL(originalURL, originalURL)
  }

  const expandedURL = new URL(expandedURLString)
  return createExpandedURL(expandedURL, originalURL)
}

function createExpandedURL(expanded: URL, original: URL): ExpandedURL {
  const url = new URL(expanded) // Copy
  return Object.assign(url, { originalURL: original })
}

export function isGoogleShortURL(url: URL): boolean {
  return parseHost(url.host).domain == 'goo.gl'
}

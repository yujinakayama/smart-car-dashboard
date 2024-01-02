import axios from 'axios'
import { wrapper as addCookieHandlingInterceptor } from 'axios-cookiejar-support'
import Encoding from 'encoding-japanese'
import iconv from 'iconv-lite'
import * as libxmljs from 'libxmljs'
import { CookieJar } from 'tough-cookie'

import { InputData } from './inputData'
import { Website } from './normalizedData'
import { urlPattern } from './util'

const axiosInstance = createAxiosInstance()

function createAxiosInstance() {
  const cookieJar = new CookieJar()

  const instance = axios.create({
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate',
      'Accept-Language': 'en,ja;q=0.9',
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15',
    },
    responseType: 'arraybuffer', // To Prevent response data from being parsed as UTF-8 by axios
    timeout: 10000,
    jar: cookieJar,
  })

  instance.interceptors.request.use((request) => {
    if (request.url) {
      const url = new URL(request.url)
      if (url.hostname == 'twitter.com') {
        // https://qiita.com/JunkiHiroi/items/f03d4297e11ce5db172e#解決時のサイトプレビュー実装user-agent-の追加
        request.headers['User-Agent'] = 'Dash Bot'
      }
    }

    return request
  })

  return addCookieHandlingInterceptor(instance)
}

export async function normalizeWebpage(inputData: InputData): Promise<Website> {
  return {
    type: 'website',
    title: await getTitle(inputData),
    url: inputData.url.toString(),
  }
}

async function getTitle(inputData: InputData): Promise<string | null> {
  let title

  const plainText = inputData.attachments['public.plain-text']

  if (plainText && !urlPattern.test(plainText)) {
    title = plainText
  } else {
    title = await fetchTitle(inputData.url)
  }

  return title?.replace(/\n/g, ' ') || null
}

export async function fetchTitle(url: URL): Promise<string | null> {
  try {
    const response = await axiosInstance.get(url.toString())
    const data = convertToUTF8String(response.data as Buffer)
    // Ignore <meta charset=shift_jis">
    const document = libxmljs.parseHtml(data, { ignore_enc: true })
    // Amazon pages may have <title> outside of <head> :(
    const titleElement = document.get('//title')

    if (!titleElement) {
      console.debug(`No <title> element found in page: ${data}`)
    }

    return titleElement?.text().trim().replace(/\n/g, ' ') ?? null
  } catch (error) {
    console.error(error)
    return null
  }
}

function convertToUTF8String(buffer: Buffer): string {
  const detectedEncoding = Encoding.detect(buffer)

  if (detectedEncoding == 'UTF8' || !detectedEncoding || !iconv.encodingExists(detectedEncoding)) {
    return buffer.toString()
  } else {
    // Not sure why but Encoding.convert() cannot convert SJIS to UTF8 properly
    return iconv.decode(buffer, detectedEncoding)
  }
}

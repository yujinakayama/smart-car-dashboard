import axios from 'axios'
import { wrapper as addCookieHandlingInterceptor } from 'axios-cookiejar-support'
import { CookieJar } from 'tough-cookie'
import * as libxmljs from 'libxmljs'

import { InputData } from './inputData'
import { Website } from './normalizedData'
import { urlPattern } from './util'

const axiosInstance = createAxiosInstance()

function createAxiosInstance() {
    const cookieJar = new CookieJar()

    const instance = axios.create({
        headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15'
        },
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
        url: inputData.url.toString()
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
        const document = libxmljs.parseHtml(response.data)
        // Amazon pages may have <title> outside of <head> :(
        return document.get('//title')?.text().trim().replace(/\n/g, ' ') || null
    } catch (error) {
        console.error(error)
        return null
    }
}

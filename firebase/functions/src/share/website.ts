import axios from 'axios';
import * as libxmljs from 'libxmljs';

import { InputData } from './inputData';
import { Website } from './normalizedData';
import { urlPattern } from './util';

// https://qiita.com/JunkiHiroi/items/f03d4297e11ce5db172e
const userAgent = 'Bot for Dash';

export async function normalizeWebpage(inputData: InputData): Promise<Website> {
    return {
        type: 'website',
        title: await getTitle(inputData),
        url: inputData.url.toString()
    };
}

async function getTitle(inputData: InputData): Promise<string | null> {
    let title;

    const plainText = inputData.attachments['public.plain-text'];

    if (plainText && !urlPattern.test(plainText)) {
        title = plainText;
    } else {
        title = await fetchTitle(inputData.url);
    }

    return title?.replace(/\n/g, ' ') || null;
}

async function fetchTitle(url: URL): Promise<string | null> {
    try {
        const response = await axios.get(url.toString(), { headers: { 'User-Agent': userAgent }});
        const document = libxmljs.parseHtml(response.data);
        return document.get('//head/title')?.text().trim().replace(/\n/g, ' ') || null;
    } catch (error) {
        console.error(error);
        return null;
    }
}

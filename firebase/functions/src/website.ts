import axios from 'axios';
import * as libxmljs from 'libxmljs';

import { InputData } from './inputData';
import { Website } from './normalizedData';
import { urlPattern } from './util';

export async function normalizeWebpage(inputData: InputData): Promise<Website> {
    return {
        type: 'website',
        title: await getTitle(inputData),
        url: inputData.url.toString()
    };
}

async function getTitle(inputData: InputData): Promise<string | null> {
    const plainText = inputData.rawData['public.plain-text'];

    if (plainText && !urlPattern.test(plainText)) {
        return plainText;
    }

    return fetchTitle(inputData.url);
}

async function fetchTitle(url: URL): Promise<string | null> {
    try {
        const response = await axios.get(url.toString());
        const document = libxmljs.parseHtml(response.data);
        return document.get('//head/title')?.text().trim() || null;
    } catch (error) {
        console.error(error);
        return null;
    }
}

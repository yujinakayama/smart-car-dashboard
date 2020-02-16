import * as request from 'request-promise';
import * as libxmljs from 'libxmljs';

import { InputData } from './inputData';
import { WebsiteData } from './normalizedData';
import { urlPattern } from './util';

export async function normalizeWebpage(inputData: InputData): Promise<WebsiteData> {
    let title = inputData.rawData['public.plain-text'];

    if (!title || urlPattern.test(title)) {
        const responseBody = await request.get(inputData.url);
        const document = libxmljs.parseHtml(responseBody);
        title = document.get('//head/title')?.text().trim();
    }

    return {
        type: 'website',
        title: title || null,
        url: inputData.url
    };
}

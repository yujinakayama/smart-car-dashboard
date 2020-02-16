import * as request from 'request-promise';
import * as libxmljs from 'libxmljs';

import { RawData } from './rawData';
import { WebsiteData } from './normalizedData';
import { urlPattern } from './util';

export const normalizeWebpage = async (rawData: RawData, url: string): Promise<WebsiteData> => {
    let title = rawData['public.plain-text'];

    if (!title || urlPattern.test(title)) {
        const responseBody = await request.get(url);
        const document = libxmljs.parseHtml(responseBody);
        title = document.get('//head/title')?.text().trim();
    }

    return {
        type: 'website',
        title: title || null,
        url: url
    };
};

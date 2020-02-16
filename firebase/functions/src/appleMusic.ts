import * as request from 'request-promise';
import * as libxmljs from 'libxmljs';

import { RawData } from './rawData';
import { MusicItemData } from './normalizedData';

export const normalizeAppleMusicItem = async (rawData: RawData, url: string): Promise<MusicItemData> => {
    let title = rawData['public.plain-text'];

    if (!title) {
        const responseBody = await request.get(url);
        const document = libxmljs.parseHtml(responseBody);
        title = document.get('//head/title')?.text().trim();
    }

    return {
        type: 'musicItem',
        title: title || null,
        url: url
    };
};

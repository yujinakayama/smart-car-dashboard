import * as request from 'request-promise';
import * as libxmljs from 'libxmljs';

import { InputData } from './inputData';
import { MusicItemData } from './normalizedData';

export async function normalizeAppleMusicItem(inputData: InputData): Promise<MusicItemData> {
    let title = inputData.rawData['public.plain-text'];

    if (!title) {
        const responseBody = await request.get(inputData.url);
        const document = libxmljs.parseHtml(responseBody);
        title = document.get('//head/title')?.text().trim();
    }

    return {
        type: 'musicItem',
        title: title || null,
        url: inputData.url
    };
}

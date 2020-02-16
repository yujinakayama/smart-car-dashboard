import * as urlRegex from 'url-regex';

export const convertAlphanumericsToAscii = (text: string | null | undefined): string | null => {
    if (!text) {
        return null;
    }

    const replaced = text.replace(/[Ａ-Ｚａ-ｚ０-９]/g, (character) => {
        return String.fromCharCode(character.charCodeAt(0) - 65248);
    });

    return replaced.replace(/−/g, '-');
};

export const urlPattern = urlRegex({ strict: true });

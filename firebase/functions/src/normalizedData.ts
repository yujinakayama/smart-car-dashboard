export interface BaseNormalizedData {
    type: string;
    url: string;
}

// Firebase doesn't allow `undefined` values
export interface LocationData extends BaseNormalizedData {
    type: 'location';
    address: Address;
    coordinate: {
        latitude: number;
        longitude: number;
    };
    name: string | null;
    websiteURL: string | null;
}

export interface Address {
    country: string | null; // 国
    prefecture: string | null; // 都道府県
    distinct: string | null; // 郡
    locality: string | null; // 市区町村
    subLocality: string | null; // 大字・字・丁目
    houseNumber: string | null; // 番地
}

export interface MusicItemData extends BaseNormalizedData {
    type: 'musicItem';
    artworkURLTemplate: string | null;
    creator: string | null;
    name: string | null;
    playParameters: {
        id: string;
        kind: string;
    } | null;
}

export interface WebsiteData extends BaseNormalizedData {
    type: 'website';
    title: string | null;
}

export type NormalizedData = LocationData | MusicItemData | WebsiteData;

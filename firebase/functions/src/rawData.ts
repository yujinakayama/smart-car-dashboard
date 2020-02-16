import { urlPattern } from './util';

export interface RawData {
    'public.url'?: string;
    'public.plain-text'?: string;
    'com.apple.mapkit.map-item'?: {
        placemark: {
            coordinate: {
                latitude: number;
                longitude: number;
            };
            isoCountryCode: string | null;
            country: string | null;
            postalCode: string | null;
            administrativeArea: string | null;
            subAdministrativeArea: string | null;
            locality: string | null;
            subLocality: string | null;
            thoroughfare: string | null;
            subThoroughfare: string | null;
        };
        name: string | null;
        phoneNumber: string | null;
        pointOfInterestCategory: string | null;
        url: string | null;
    };
}

export const extractURL = (rawData: RawData): string | null => {
    if (rawData['public.url']) {
        return rawData['public.url']
    }

    if (rawData['public.plain-text']) {
        const urls = rawData['public.plain-text'].match(urlPattern);

        if (urls && urls[0]) {
            return urls[0];
        }
    }

    return null;
}

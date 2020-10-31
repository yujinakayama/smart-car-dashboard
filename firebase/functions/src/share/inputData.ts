import { URL } from 'url';

import { urlPattern } from './util';

export interface Request {
    vehicleID: string;
    item: RawInputData;
}

export class InputData {
    rawData: RawInputData;
    url: URL;

    constructor(rawData: RawInputData) {
        this.rawData = rawData;
        this.url = new URL(this.extractURL());
    }

    private extractURL(): string {
        if (this.rawData['public.url']) {
            return this.rawData['public.url'];
        }

        if (this.rawData['public.plain-text']) {
            const urls = this.rawData['public.plain-text'].match(urlPattern);

            if (urls && urls[0]) {
                return urls[0];
            }
        }

        throw new Error('RawInputData has no URL');
    }
}

export interface RawInputData {
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

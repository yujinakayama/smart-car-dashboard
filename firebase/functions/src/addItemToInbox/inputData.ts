import { URL } from 'url'

import { urlPattern } from './util'

export interface Request {
    vehicleID: string;
    attachments: Attachments;
}

export class InputData {
    attachments: Attachments
    url: URL

    constructor(attachments: Attachments) {
        this.attachments = attachments
        this.url = new URL(this.extractURL())
    }

    private extractURL(): string {
        if (this.attachments['public.url']) {
            return this.attachments['public.url']
        }

        if (this.attachments['public.plain-text']) {
            const urls = this.attachments['public.plain-text'].match(urlPattern)

            if (urls && urls[0]) {
                return urls[0]
            }
        }

        throw new Error('Attachments have no URL')
    }
}

export interface Attachments {
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

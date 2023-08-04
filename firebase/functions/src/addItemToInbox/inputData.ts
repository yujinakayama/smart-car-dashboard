import { URL } from 'url'

import { urlPattern } from './util'
import axios from 'axios'

export interface Request {
    vehicleID: string;
    attachments: Attachments;
    notification?: boolean;
}

export class InputData {
    attachments: Attachments
    url: URL
    private _expandedURL: URL | undefined

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

    async expandURL(): Promise<URL> {
        if (this._expandedURL) {
            return this._expandedURL
        }

        const response = await axios.get(this.url.toString(), {
            maxRedirects: 0,
            validateStatus: () => true
        })

        const expandedURLString = response.headers['location']

        if (expandedURLString) {
            this._expandedURL = new URL(expandedURLString)
            return this._expandedURL
        } else {
            throw new Error(`URL could not be expanded: ${this.url.toString()}`)
        }
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

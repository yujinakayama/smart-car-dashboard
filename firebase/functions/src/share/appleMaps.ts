import { InputData } from './inputData';
import { Location } from './normalizedData';

export function isAppleMapsLocation(inputData: InputData): boolean {
    return !!inputData.attachments['com.apple.mapkit.map-item'];
}

export async function normalizeAppleMapsLocation(inputData: InputData): Promise<Location> {
    const mapItem = inputData.attachments['com.apple.mapkit.map-item']!;

    return {
        type: 'location',
        address: {
            country: mapItem.placemark.country,
            prefecture: mapItem.placemark.administrativeArea,
            distinct: null,
            locality: mapItem.placemark.locality,
            subLocality: mapItem.placemark.thoroughfare,
            houseNumber: mapItem.placemark.subThoroughfare
        },
        coordinate: mapItem.placemark.coordinate,
        name: mapItem.name,
        websiteURL: mapItem.url,
        url: inputData.url.toString()
    };
}

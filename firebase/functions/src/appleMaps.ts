import { InputData } from './inputData';
import { LocationData } from './normalizedData';

export async function normalizeAppleMapsLocation(inputData: InputData): Promise<LocationData> {
    const mapItem = inputData.rawData['com.apple.mapkit.map-item']!;

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

import { normalizeCategory } from './appleMaps'

describe(normalizeCategory, () => {
    test.each([
        ['MKPOICategoryAirport',       ['airport']],
        ['MKPOICategoryAmusementPark', ['amusementPark']],
        ['MKPOICategoryATM',           ['atm']],
        ['MKPOICategoryEVCharger',     ['evCharger']],
    ])('normalizes %s to %s', (mapKitCategory, expected) => {
        expect(normalizeCategory(mapKitCategory)).toEqual(expected)
    })
})

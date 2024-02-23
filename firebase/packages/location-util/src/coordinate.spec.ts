import { Coordinate, distanceBetween } from './coordinate'

describe('distanceBetween()', () => {
  it('returns distance between the given two coordinates in meters', () => {
    const otemachi: Coordinate = {
      latitude: 35.68532114535532,
      longitude: 139.76316472427692,
    }

    const hibiya: Coordinate = {
      latitude: 35.67507001768744,
      longitude: 139.75963309349277,
    }

    expect(distanceBetween(otemachi, hibiya)).toBeCloseTo(1221, 0)
  })
})

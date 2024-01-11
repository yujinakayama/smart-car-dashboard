export interface Coordinate {
  latitude: number
  longitude: number
}

// https://simplesimples.com/web/markup/javascript/exchange_latlng_javascript/
export class TokyoDatumCoordinate {
  constructor(
    public latitude: number,
    public longitude: number,
  ) {}

  get worldGeodeticSystemCoordinate(): Coordinate {
    return {
      latitude:
        this.latitude - this.latitude * 0.00010695 + this.longitude * 0.000017464 + 0.0046017,
      longitude:
        this.longitude - this.latitude * 0.000046038 - this.longitude * 0.000083043 + 0.01004,
    }
  }
}

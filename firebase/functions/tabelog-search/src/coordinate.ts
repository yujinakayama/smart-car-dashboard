export interface Coordinate {
  latitude: number
  longitude: number
}

// Returns distance between two coordinates in meters
export function distanceBetween(coodinateA: Coordinate, coordinateB: Coordinate): number {
  const latitudeA = degreeToRadian(coodinateA.latitude)
  const longitudeA = degreeToRadian(coodinateA.longitude)
  const latitudeB = degreeToRadian(coordinateB.latitude)
  const longitudeB = degreeToRadian(coordinateB.longitude)

  // Radius of the Earth in meters
  const radius = 6571 * 1000

  // Haversine equation
  return (
    Math.acos(
      Math.sin(latitudeA) * Math.sin(latitudeB) +
        Math.cos(latitudeA) * Math.cos(latitudeB) * Math.cos(longitudeA - longitudeB),
    ) * radius
  )
}

function degreeToRadian(degree: number): number {
  return (degree * Math.PI) / 180
}

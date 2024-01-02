// https://stackoverflow.com/a/34275131/784241

enum PrimitiveType {
  Unknown = -1,
  Map = 1,
  Float,
  Double,
  Integer,
  UnsignedInteger,
  Enum,
  Boolean,
  String,
}

const PrimitiveTypeMap: { [key: string]: PrimitiveType } = {
  m: PrimitiveType.Map,
  f: PrimitiveType.Float,
  d: PrimitiveType.Double,
  i: PrimitiveType.Integer,
  u: PrimitiveType.UnsignedInteger,
  e: PrimitiveType.Enum,
  b: PrimitiveType.Boolean,
  s: PrimitiveType.String,
}

type KeyValue = { [key: string]: any }

class Data {
  place?: Place

  constructor(object: KeyValue) {
    this.place = object['4'] && new Place(object['4'])
  }
}

class Place {
  geometry?: Geometry

  constructor(object: KeyValue) {
    this.geometry = object['3'] && new Geometry(object['3'])
  }
}

class Geometry {
  ftid?: string
  location?: Location

  constructor(object: KeyValue) {
    const identifier = object['1']

    if (identifier.startsWith('0x')) {
      this.ftid = identifier
    }

    this.location = object['8'] && new Location(object['8'])
  }
}

class Location {
  latitude?: string
  longitude?: string

  constructor(object: KeyValue) {
    this.latitude = object['3']
    this.longitude = object['4']
  }
}

export function decodeURLDataParameter(data: string): Data {
  const elements = data.split('!').filter((element) => element.length > 0)
  const object = parseElementsAsPrimitives(elements)
  return new Data(object)
}

function parseElementsAsPrimitives(remainingElements: string[]): KeyValue {
  const object = {}

  while (true) {
    const keyValue = parseElementAsPrimitive(remainingElements)

    if (keyValue) {
      Object.assign(object, keyValue)
    } else {
      return object
    }
  }
}

function parseElementAsPrimitive(remainingElements: string[]): KeyValue | null {
  const element = remainingElements.shift()

  if (!element) {
    return null
  }

  const key = element[0]
  const type = PrimitiveTypeMap[element[1]] || PrimitiveType.Unknown
  const body = element.slice(2)

  switch (type) {
    case PrimitiveType.Map: {
      const childCount = Number(body)
      const childElements = []
      for (let index = 0; index < childCount; index++) {
        const childElement = remainingElements.shift()
        if (!childElement) {
          throw new Error(
            `The map ${element} must have ${childCount} children but there're not enough remaining elements`,
          )
        }
        childElements.push(childElement)
      }
      return { [key]: parseElementsAsPrimitives(childElements) }
    }
    case PrimitiveType.Float:
    case PrimitiveType.Double:
    case PrimitiveType.Integer:
    case PrimitiveType.UnsignedInteger:
    case PrimitiveType.Enum:
    case PrimitiveType.String:
      return { [key]: body }
    case PrimitiveType.Boolean:
      return { [key]: body === '1' }
    default:
      return { [key]: body }
  }
}

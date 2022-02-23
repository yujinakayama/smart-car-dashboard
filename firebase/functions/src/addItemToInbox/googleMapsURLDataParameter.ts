// https://stackoverflow.com/a/34275131/784241

enum ValueType {
    Unknown = -1,
    Map = 1,
    Float,
    Double,
    Integer,
    UnsignedInteger,
    Enum,
    Boolean,
    String,
};
  
const ValueTypeMap: { [key: string]: ValueType } = {
    m: ValueType.Map,
    f: ValueType.Float,
    d: ValueType.Double,
    i: ValueType.Integer,
    u: ValueType.UnsignedInteger,
    e: ValueType.Enum,
    b: ValueType.Boolean,
    s: ValueType.String,
}

type KeyValue = { [key: string]: any };

class Data {
    place?: Place;

    constructor(object: any) {
        this.place = object['4'] && new Place(object['4']);
    }
}

class Place {
    geometry?: Geometry;

    constructor(object: any) {
        this.geometry = object['3'] && new Geometry(object['3']);
    }
}

class Geometry {
    ftid?: string;
    location?: Location;

    constructor(object: any) {
        this.ftid = object['1'];
        this.location = object['8'] && new Location(object['8']);
    }
}

class Location {
    latitude?: string;
    longitude?: string;

    constructor(object: any) {
        this.latitude = object['3'];
        this.longitude = object['4'];
    }
}

export function decodeURLDataParameter(data: string): Data {
    const elements = data.split('!').filter(element => element.length > 0);
    const object = parseElements(elements);
    return new Data(object);
}

function parseElements(remainingElements: string[]): {} {
    const object = {};

    while (true) {
        const keyValue = parseElement(remainingElements)

        if (keyValue) {
            Object.assign(object, keyValue);
        } else {
            return object;
        }
    }
}

function parseElement(remainingElements: string[]): KeyValue | null {
    const element = remainingElements.shift();

    if (!element) {
        return null;
    }

    const key = element[0];
    const type = ValueTypeMap[element[1]] || ValueType.Unknown;
    const body = element.slice(2);

    switch (type) {
        case ValueType.Map:
            const childCount = Number(body);
            const childElements = [];
            for (let index = 0; index < childCount; index++) {
                const childElement = remainingElements.shift()
                if (!childElement) {
                    throw new Error(`The map ${element} must have ${childCount} children but there're not enough remaining elements`);
                }
                childElements.push(childElement);
            }
            return { [key]: parseElements(childElements) };
        case ValueType.Float:
        case ValueType.Double:
        case ValueType.Integer:
        case ValueType.UnsignedInteger:
        case ValueType.Enum:
        case ValueType.String:
            return { [key]: body };
        case ValueType.Boolean:
            return { [key]: body === '1' };
        default:
            return { [key]: body };
    }
}

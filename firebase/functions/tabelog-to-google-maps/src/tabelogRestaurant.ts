export interface TabelogRestaurant {
  name?: string
  phoneNumber?: string
  address?: string
  url?: string
}

export function parseTabelogRestaurantText(text: string): TabelogRestaurant {
  const lines = text.split(/\r?\n/).map((line) => line.trim())
  const restaurant: TabelogRestaurant = {}

  for (const line of lines) {
    if (line == '') continue

    if (line.match(/^\d[\d-]+\d$/)) {
      restaurant.phoneNumber = line
    } else if (line.match(/^http/)) {
      restaurant.url = line
    } else if (line.match(/^.{2,3}[都道府県]/)) {
      restaurant.address = line
    } else {
      restaurant.name = line
    }
  }

  return restaurant
}

import { parseTabelogRestaurantText } from './tabelogRestaurant'

describe('parseTabelogRestaurantText()', () => {
  describe('with full information', () => {
    it('returns parsed restaurant information', () => {
      const text = [
        'ルフージュ',
        '03-6252-4588',
        '東京都中央区銀座8-2-8 銀座高本ビル1Ｆ',
        'https://tabelog.com/tokyo/A1301/A130103/13126959/',
      ].join('\n')

      expect(parseTabelogRestaurantText(text)).toEqual({
        address: '東京都中央区銀座8-2-8 銀座高本ビル1Ｆ',
        name: 'ルフージュ',
        phoneNumber: '03-6252-4588',
        url: 'https://tabelog.com/tokyo/A1301/A130103/13126959/',
      })
    })
  })

  describe('with only URL', () => {
    it('returns parsed restaurant information', () => {
      const text = 'https://tabelog.com/tokyo/A1301/A130103/13126959/'

      expect(parseTabelogRestaurantText(text)).toEqual({
        url: 'https://tabelog.com/tokyo/A1301/A130103/13126959/',
      })
    })
  })

  describe('with empty text', () => {
    it('returns empty information', () => {
      expect(parseTabelogRestaurantText('')).toEqual({})
    })
  })
})

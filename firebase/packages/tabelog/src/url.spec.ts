import { extractRestaurantIDFromURL } from './url'

describe('extractRestaurantIDFromURL()', () => {
  describe('with a top page URL of a restaurant', () => {
    it('returns the restaurant ID', () => {
      expect(
        extractRestaurantIDFromURL('https://tabelog.com/tokyo/A1301/A130102/13168901/'),
      ).toEqual(13168901)
    })
  })

  describe('with a photo list page URL of a restaurant', () => {
    it('returns the restaurant ID', () => {
      expect(
        extractRestaurantIDFromURL(
          'https://tabelog.com/tokyo/A1301/A130102/13168901/dtlphotolst/smp2/',
        ),
      ).toEqual(13168901)
    })
  })

  describe('with a top page URL of a restaurant for smartphones', () => {
    it('returns the restaurant ID', () => {
      expect(
        extractRestaurantIDFromURL('https://s.tabelog.com/tokyo/A1301/A130102/13168901/'),
      ).toEqual(13168901)
    })
  })

  describe('with a English top page URL of a restaurant', () => {
    it('returns the restaurant ID', () => {
      expect(
        extractRestaurantIDFromURL('https://tabelog.com/en/tokyo/A1301/A130102/13168901/'),
      ).toEqual(13168901)
    })
  })

  describe('with a Taiwanese top page URL of a restaurant', () => {
    it('returns the restaurant ID', () => {
      expect(
        extractRestaurantIDFromURL('https://tabelog.com/tw/tokyo/A1301/A130102/13168901/'),
      ).toEqual(13168901)
    })
  })

  describe('with a restaurant search page URL', () => {
    it('returns null', () => {
      expect(
        extractRestaurantIDFromURL('https://tabelog.com/kyoto/A2601/A260201/R4596/'),
      ).toBeNull()
    })
  })

  describe('with an invalid URL string', () => {
    it('throws an error', () => {
      expect(() => extractRestaurantIDFromURL('?')).toThrow('Invalid URL')
    })
  })
})

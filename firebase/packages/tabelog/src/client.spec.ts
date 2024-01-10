import * as uuid from 'uuid'

import { Client } from './client'
import { RecordReplayProxy, startRecordReplayProxy } from './testHelpers/RecordReplayProxy'

describe('Client', () => {
  let client: Client
  let proxy: RecordReplayProxy

  beforeAll(async () => {
    proxy = await startRecordReplayProxy({
      targetOrigin: Client.defaultBaseURL,
      localhostPort: 8888,
      ignoreHeaders: [
        'x-tabelog-secret-token',
        'x-tabelog-appli-device-id',
        'x-tabelog-appli-unique-id',
      ],
    })
  })

  afterAll(async () => {
    await proxy.stop()
  })

  beforeEach(() => {
    client = new Client({
      baseURL: `http://localhost:${proxy.options.localhostPort}`,
      deviceID: uuid.v4(),
      secretToken: requireEnv('TABELOG_SECRET_TOKEN'),
    })
  })

  describe('getRestaurant()', () => {
    describe('with a restaurant ID', () => {
      it('returns the restaurant info', async () => {
        expect(await client.getRestaurant(13168901)).toEqual({
          address: '東京都千代田区有楽町2-7-1 有楽町マルイ 5F',
          averageBudget: {
            dinner: '￥1,000～￥1,999',
            granularity: 'M',
            lunch: '￥1,000～￥1,999',
          },
          coordinate: {
            granularity: 'M',
            latitude: 35.67117008277395,
            longitude: 139.7668109175149,
          },
          genres: ['カフェ', 'スイーツ', '野菜料理'],
          id: 13168901,
          name: '24/7 cafe apartment 有楽町',
          reviewCount: 260,
          score: 3.47,
          webURL: new URL('https://tabelog.com/tokyo/A1301/A130102/13168901/'),
        })
      })
    })

    describe('with a less informative restaurant ID', () => {
      it('returns the restaurant info', async () => {
        expect(await client.getRestaurant(13263973)).toEqual({
          address: '東京都渋谷区初台1-10-2 パークホームズ初台',
          averageBudget: {
            dinner: '',
            granularity: 'M',
            lunch: '',
          },
          coordinate: {
            granularity: 'M',
            latitude: 35.67554248871983,
            longitude: 139.69017645487077,
          },
          genres: ['コンビニ・スーパー'],
          id: 13263973,
          name: 'まいばすけっと 初台駅南店',
          reviewCount: 0,
          score: 0,
          webURL: new URL('https://tabelog.com/tokyo/A1318/A131807/13263973/'),
        })

        expect(await client.getRestaurant(24016807)).toEqual({
          address: '三重県名張市桔梗が丘2-4-28 ',
          averageBudget: {
            dinner: '￥2,000～￥2,999',
            granularity: 'M',
            lunch: '',
          },
          coordinate: {
            granularity: 'M',
            latitude: 34.637370833333335,
            longitude: 136.11951277777777,
          },
          genres: ['バー'],
          id: 24016807,
          name: 'バー ロール',
          reviewCount: 0,
          score: 0,
          webURL: new URL('https://tabelog.com/mie/A2404/A240402/24016807/'),
        })
      })
    })

    describe('with a hyakumeiten restaurant ID', () => {
      it('returns the restaurant info', async () => {
        expect(await client.getRestaurant(26029810)).toEqual({
          address: '京都府京都市下京区泉正寺町463 ルネ丸高1F',
          averageBudget: {
            dinner: '￥1,000～￥1,999',
            granularity: 'M',
            lunch: '￥1,000～￥1,999',
          },
          coordinate: {
            granularity: 'M',
            latitude: 34.996751521162736,
            longitude: 135.76610663424336,
          },
          genres: ['ラーメン'],
          id: 26029810,
          name: '麺屋 猪一 離れ',
          reviewCount: 560,
          score: 3.68,
          webURL: new URL('https://tabelog.com/kyoto/A2601/A260201/26029810/'),
        })
      })
    })
  })
})

function requireEnv(name: string): string {
  const value = process.env[name]
  if (!value) {
    throw new Error(`Environment variable ${name} is missing`)
  }
  return value
}

import { URL } from 'url'
import { Client } from '@yujinakayama/apple-music'
import { InputData } from './inputData'
import { MusicItem } from './normalizedData'
import jwt from 'jsonwebtoken'

interface AppleMusicData {
  artworkURLTemplate: string | null
  creator: string | null
  name: string
  playParameters: {
    id: string
    kind: string
  } | null
}

interface ItemParameters {
  storefront: string
  type: string
  id: string
  songID: string | null
}

const keyIDEnvName = 'APPLE_MUSIC_KEY_ID'
const privateKeyEnvName = 'APPLE_MUSIC_PRIVATE_KEY'
const teamIDEnvName = 'APPLE_MUSIC_TEAM_ID'

export const requiredEnvNames = [keyIDEnvName, privateKeyEnvName, teamIDEnvName]

export function isAppleMusicItem(inputData: InputData): boolean {
  return extractItemParameters(inputData.url) !== null
}

export async function normalizeAppleMusicItem(inputData: InputData): Promise<MusicItem> {
  const data: MusicItem = {
    type: 'musicItem',
    artworkURLTemplate: null,
    creator: null,
    name: null,
    playParameters: null,
    url: inputData.url.toString(),
  }

  const appleMusicData = await fetchDataFromAppleMusic(inputData.url)

  if (!appleMusicData) {
    return data
  }

  return { ...data, ...appleMusicData }
}

async function fetchDataFromAppleMusic(url: URL): Promise<AppleMusicData | null> {
  const itemParameters = extractItemParameters(url)

  if (!itemParameters) {
    return null
  }

  const client = createClient()
  const { storefront, type, id, songID } = itemParameters

  if (songID) {
    const song = (await client.songs.get(songID, { storefront })).data[0]
    return {
      artworkURLTemplate: song.attributes!.artwork.url,
      creator: song.attributes!.artistName,
      name: song.attributes!.name,
      playParameters: song.attributes!.playParams || null,
    }
  }

  switch (type) {
    case 'album': {
      const album = (await client.albums.get(id, { storefront })).data[0]
      return {
        artworkURLTemplate: album.attributes!.artwork?.url || null,
        creator: album.attributes!.artistName,
        name: album.attributes!.name,
        playParameters: album.attributes!.playParams || null,
      }
    }
    case 'artist': {
      const artist = (await client.artists.get(id, { storefront })).data[0]
      return {
        artworkURLTemplate: null,
        creator: null,
        name: artist.attributes!.name,
        playParameters: null,
      }
    }
    case 'music-video': {
      const musicVideo = (await client.musicVideos.get(id, { storefront })).data[0]
      return {
        artworkURLTemplate: musicVideo.attributes!.artwork.url,
        creator: musicVideo.attributes!.artistName,
        name: musicVideo.attributes!.name,
        playParameters: musicVideo.attributes!.playParams || null,
      }
    }
    case 'playlist': {
      const playlist = (await client.playlists.get(id, { storefront })).data[0]
      console.log(playlist)
      return {
        artworkURLTemplate: playlist.attributes!.artwork?.url || null,
        creator: playlist.attributes!.curatorName || null,
        name: playlist.attributes!.name,
        playParameters: playlist.attributes!.playParams || null,
      }
    }
    case 'station': {
      const station = (await client.stations.get(id, { storefront })).data[0]
      return {
        artworkURLTemplate: station.attributes!.artwork.url,
        creator: null,
        name: station.attributes!.name,
        playParameters: station.attributes!.playParams || null,
      }
    }
    default:
      return null
  }
}

function extractItemParameters(url: URL): ItemParameters | null {
  if (url.host !== 'music.apple.com') {
    return null
  }

  // https://music.apple.com/jp/artist/adele/262836961?l=en
  // https://music.apple.com/jp/album/1581087024?l=en
  // https://music.apple.com/jp/album/bad-habits/1581087024?i=1581087532&l=en
  // https://music.apple.com/jp/playlist/japan-hits-2021/pl.f1634b3ba5414e19b71303f670640f6a?l=en
  const [, storefront, type, ...idCandidates] = url.pathname.split('/')
  const id = idCandidates.pop()

  if (!storefront || !type || !id) {
    return null
  }

  return {
    storefront,
    type,
    id,
    songID: url.searchParams.get('i'),
  }
}

function createClient(): Client {
  const developerToken = generateDeveloperToken(
    requireEnv(keyIDEnvName),
    requireEnv(privateKeyEnvName),
    requireEnv(teamIDEnvName),
  )

  return new Client({
    developerToken: developerToken,
  })
}

function generateDeveloperToken(keyID: string, privateKey: string, teamID: string): string {
  return jwt.sign({}, privateKey, {
    algorithm: 'ES256',
    expiresIn: 60,
    issuer: teamID,
    header: {
      alg: 'ES256',
      kid: keyID,
    },
  })
}

function requireEnv(name: string): string {
  const value = process.env[name]
  if (!value) {
    throw new Error(`Env ${name} is missing`)
  }
  return value
}

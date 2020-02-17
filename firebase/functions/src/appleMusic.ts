import * as functions from 'firebase-functions';

import { URL } from 'url';

import { Client } from './appleMusicClient';
import { InputData } from './inputData';
import { MusicItemData } from './normalizedData';

interface AppleMusicData {
    artworkURLTemplate: string | null,
    creator: string | null;
    name: string,
    playParameters: {
        id: string;
        kind: string;
    } | null;
}

const client = new Client(functions.config().apple_music.developer_token)

export function isAppleMusicItem(inputData: InputData): boolean {
    let url = inputData.url;
    return url.host == 'music.apple.com' && url.pathname.split('/').length >= 5
}

export async function normalizeAppleMusicItem(inputData: InputData): Promise<MusicItemData> {
    const data: MusicItemData = {
        type: 'musicItem',
        artworkURLTemplate: null,
        creator: null,
        name: null,
        playParameters: null,
        url: inputData.url.toString()
    };

    const appleMusicData = await fetchDataFromAppleMusic(inputData.url);

    if (!appleMusicData) {
        return data;
    }

    return {...data, ...appleMusicData};
}

async function fetchDataFromAppleMusic(webURL: URL): Promise<AppleMusicData | null> {
    const [, storefront, type, , id] = webURL.pathname.split('/');

    const songID = webURL.searchParams.get('i')

    if (songID) {
        const song = (await client.songs.get(songID, storefront)).data[0];
        return {
            artworkURLTemplate: song.attributes!.artwork.url,
            creator: song.attributes!.artistName,
            name: song.attributes!.name,
            playParameters: song.attributes!.playParams || null
        };
    }

    switch (type) {
        case 'album':
            const album = (await client.albums.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: album.attributes!.artwork?.url || null,
                creator: album.attributes!.artistName,
                name: album.attributes!.name,
                playParameters: album.attributes!.playParams || null
            };
        case 'artist':
            const artist = (await client.artists.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: null,
                creator: null,
                name: artist.attributes!.name,
                playParameters: null
            };
        case 'music-video':
            const musicVideo = (await client.musicVideos.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: musicVideo.attributes!.artwork.url,
                creator: musicVideo.attributes!.artistName,
                name: musicVideo.attributes!.name,
                playParameters: musicVideo.attributes!.playParams || null
            };
        case 'playlist':
            const playlist = (await client.playlists.get(id, storefront)).data[0];
            console.log(playlist);
            return {
                artworkURLTemplate: playlist.attributes!.artwork?.url || null,
                creator: playlist.attributes!.curatorName || null,
                name: playlist.attributes!.name,
                playParameters: playlist.attributes!.playParams || null
            };
        case 'station':
            const station = (await client.stations.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: station.attributes!.artwork.url,
                creator: null,
                name: station.attributes!.name,
                playParameters: station.attributes!.playParams || null
            };
        default:
            return null;
    }
}

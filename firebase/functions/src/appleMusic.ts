import * as functions from 'firebase-functions';

import { URL } from 'url';

import { Client } from './appleMusicClient';
import { InputData } from './inputData';
import { MusicItemData } from './normalizedData';

interface AppleMusicData {
    artworkURLTemplate: string | null,
    creator: string | null;
    id: string,
    name: string
}

const client = new Client(functions.config().apple_music.developer_token)

export async function normalizeAppleMusicItem(inputData: InputData): Promise<MusicItemData> {
    const data: MusicItemData = {
        type: 'musicItem',
        artworkURLTemplate: null,
        creator: null,
        id: null,
        name: null,
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

    if (!storefront || !type || !id) {
        return null;
    }

    const songID = webURL.searchParams.get('i')

    if (songID) {
        const song = (await client.songs.get(songID, storefront)).data[0];
        return {
            artworkURLTemplate: song.attributes!.artwork.url,
            creator: song.attributes!.artistName,
            id: song.id,
            name: song.attributes!.name
        };
    }

    switch (type) {
        case 'album':
            const album = (await client.albums.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: album.attributes!.artwork?.url || null,
                creator: album.attributes!.artistName,
                id: album.id,
                name: album.attributes!.name
            };
        case 'artist':
            const artist = (await client.artists.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: null,
                creator: null,
                id: artist.id,
                name: artist.attributes!.name
            };
        case 'music-video':
            const musicVideo = (await client.musicVideos.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: musicVideo.attributes!.artwork.url,
                creator: musicVideo.attributes!.artistName,
                id: musicVideo.id,
                name: musicVideo.attributes!.name
            };
        case 'playlist':
            const playlist = (await client.playlists.get(id, storefront)).data[0];
            console.log(playlist);
            return {
                artworkURLTemplate: playlist.attributes!.artwork?.url || null,
                creator: playlist.attributes!.curatorName || null,
                id: playlist.id,
                name: playlist.attributes!.name
            };
        case 'station':
            const station = (await client.stations.get(id, storefront)).data[0];
            return {
                artworkURLTemplate: station.attributes!.artwork.url,
                creator: null,
                id: station.id,
                name: station.attributes!.name
            };
        default:
            return null;
    }
}

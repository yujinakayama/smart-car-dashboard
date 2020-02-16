import * as functions from 'firebase-functions';
import * as request from 'request-promise';

import { URL } from 'url';

import { InputData } from './inputData';
import { MusicItemData } from './normalizedData';

import { ResponseRoot } from './appleMusic/responseRoot';
import { AlbumResponse } from './appleMusic/albumResponse';
import { ArtistResponse } from './appleMusic/artistResponse';
import { SongResponse } from './appleMusic/songResponse';
import { MusicVideoResponse } from './appleMusic/musicVideoResponse';
import { PlaylistResponse } from './appleMusic/playlistResponse';
import { StationResponse } from './appleMusic/stationResponse';

export class Client {
    configuration: ClientConfiguration

    albums: ResourceClient<AlbumResponse>;
    artists: ResourceClient<ArtistResponse>;
    songs: ResourceClient<SongResponse>;
    musicVideos: ResourceClient<MusicVideoResponse>;
    playlists: ResourceClient<PlaylistResponse>;
    stations: ResourceClient<StationResponse>;

    constructor(developerToken: string, defaultStorefront?: string) {
        this.configuration = {
            developerToken,
            defaultStorefront
        };

        this.albums = new ResourceClient<AlbumResponse>('albums', this.configuration);
        this.artists = new ResourceClient<ArtistResponse>('artists', this.configuration);
        this.songs = new ResourceClient<SongResponse>('songs', this.configuration);
        this.musicVideos = new ResourceClient<MusicVideoResponse>('music-videos', this.configuration);
        this.playlists = new ResourceClient<PlaylistResponse>('playlists', this.configuration);
        this.stations = new ResourceClient<StationResponse>('stations', this.configuration);
    }
}

interface ClientConfiguration {
    developerToken: string;
    defaultStorefront?: string;
}

class ResourceClient<T extends ResponseRoot> {
    constructor(public urlName: string, public configuration: ClientConfiguration) {
    }

    async get(id: string, storefront?: string): Promise<T> {
        const requiredStorefront = storefront || this.configuration.defaultStorefront;

        if (!requiredStorefront) {
            throw new Error(`Specify storefront with function parameter or default one with Client's constructor`)
        }

        const url = `https://api.music.apple.com/v1/catalog/${requiredStorefront}/${this.urlName}/${id}`
        const json = await this.request('GET', url);
        const response = parseJSONWithDateHandling(json);
        return response;
    }

    private request(method: string, url: string): request.RequestPromise {
        return request({
            method: method,
            url: url,
            headers: {
                'Authorization': `Bearer ${this.configuration.developerToken}`
            }
        })
    }
}

const datePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/

function parseJSONWithDateHandling(json: string) {
    return JSON.parse(json, (key: any, value: any) => {
        if (typeof (value) === 'string' && value.match(datePattern)) {
            return new Date(value);
        } else {
            return value;
        }
    });
}

const client = new Client(functions.config().apple_music.developer_token)

export async function normalizeAppleMusicItem(inputData: InputData): Promise<MusicItemData> {
    const data: MusicItemData = {
        type: 'musicItem',
        artworkURLTemplate: null,
        creator: null,
        id: null,
        name: null,
        url: inputData.url
    };

    const appleMusicData = await fetchDataFromAppleMusic(inputData.url);

    if (!appleMusicData) {
        return data;
    }

    return {...data, ...appleMusicData};
}

interface AppleMusicData {
    artworkURLTemplate: string | null,
    creator: string | null;
    id: string,
    name: string
}

async function fetchDataFromAppleMusic(webURL: string): Promise<AppleMusicData | null> {
    const url = new URL(webURL);
    const [, storefront, type, , id] = url.pathname.split('/');

    if (!storefront || !type || !id) {
        return null;
    }

    const songID = url.searchParams.get('i')

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

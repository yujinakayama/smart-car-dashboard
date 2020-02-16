import * as request from 'request-promise';

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

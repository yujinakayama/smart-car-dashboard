import { google } from 'googleapis'
import * as functions from 'firebase-functions'

import { InputData } from './inputData'
import { Video } from './normalizedData'

const client = google.youtube('v3')

const apiKey = process.env.GOOGLE_API_KEY || functions.config().google.api_key

export function isYouTubeVideo(inputData: InputData): boolean {
    const url = inputData.url

    if (url.toString().startsWith('https://youtu.be/')) {
        return true
    }

    return !!url.hostname.match(/(www\.)?youtube\.com/)
        && url.pathname === '/watch'
        && url.searchParams.has('v')
}

export async function normalizeYouTubeVideo(inputData: InputData): Promise<Video> {
    const videoID = inputData.url.searchParams.get('v')

    if (!videoID) {
        throw new Error(`YouTube URL must have a video ID: ${inputData.url}`)
    }

    const response = await client.videos.list({
        id: [videoID],
        part: ['snippet'],
        auth: apiKey
    })

    const video = response.data.items?.[0]

    if (!video) {
        throw new Error(`Failed fetching data for YouTube video: ${response.statusText}`)
    }
  
    const snippet = video.snippet!

    return {
        type: 'video',
        creator: snippet.channelTitle || null,
        title: snippet.title || null,
        thumbnailURL: snippet.thumbnails?.default?.url || null,
        url: inputData.url.toString()
    }
}

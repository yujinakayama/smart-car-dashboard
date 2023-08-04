import { google, youtube_v3 } from 'googleapis'

import { InputData } from './inputData'
import { Video } from './normalizedData'

export const requiredEnvName = 'GOOGLE_API_KEY'
const apiKey = process.env[requiredEnvName]

const client = google.youtube('v3')

export async function isYouTubeVideo(inputData: InputData): Promise<boolean> {
    let url = inputData.url

    if (url.host == 'youtu.be') {
        url = await inputData.expandURL()
    }

    return !!url.hostname.match(/(www\.)?youtube\.com/)
        && url.pathname === '/watch'
        && url.searchParams.has('v')
}

export async function normalizeYouTubeVideo(inputData: InputData): Promise<Video> {
    const expandedURL = await inputData.expandURL()
    const videoID = expandedURL.searchParams.get('v')

    if (!videoID) {
        throw new Error(`YouTube URL must have a video ID: ${inputData.url}`)
    }

    const video = await fetchVideo(videoID)

    let channel: youtube_v3.Schema$ChannelSnippet | null = null

    if (video.channelId) {
        channel = await fetchChannel(video.channelId)
    }

    return {
        type: 'video',
        creator: video.channelTitle || null,
        title: video.title || null,
        thumbnailURL: channel?.thumbnails?.medium?.url || null,
        url: inputData.url.toString()
    }
}

async function fetchVideo(id: string): Promise<youtube_v3.Schema$VideoSnippet> {
    const response = await client.videos.list({
        id: [id],
        part: ['snippet'],
        auth: apiKey
    })

    const video = response.data.items?.[0]

    if (!video) {
        throw new Error(`Failed fetching data for YouTube video: ${response.statusText}`)
    }

    return video.snippet!
}

async function fetchChannel(id: string): Promise<youtube_v3.Schema$ChannelSnippet> {
    const response = await client.channels.list({
        id: [id],
        part: ['snippet'],
        auth: apiKey
    })

    const channel = response.data.items?.[0]

    if (!channel) {
        throw new Error(`Failed fetching data for YouTube channel: ${response.statusText}`)
    }

    return channel.snippet!
}

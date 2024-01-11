import axios, { AxiosInstance, AxiosPromise, Method } from 'axios'

import { restaurantDetailShowResponseSchema } from './apiSchema'
import { TokyoDatumCoordinate } from './coordinate'
import { Restaurant } from './restaurant'

export interface ClientOptions {
  baseURL?: string
  deviceID: string // UUID v4
  secretToken: string
}

export class Client {
  static defaultBaseURL = 'https://api.tabelog.com'

  private axiosInstance: AxiosInstance

  constructor(options: ClientOptions) {
    this.axiosInstance = axios.create({
      baseURL: options.baseURL ?? Client.defaultBaseURL,
      headers: {
        'X-Tabelog-OS-Version': 'iOS 17.2.1',
        'X-Tabelog-Appli-Version': 'Tabelog iPhone/ver9.87.0',
        'X-Tabelog-Secret-Token': options.secretToken,
        'X-Tabelog-Locale': 'ja_JP',
        'X-Tabelog-Appli-Device-ID': options.deviceID,
        'X-Tabelog-Device-Model': 'iPhone14,2',
        'User-Agent': 'Tabelog iPhone/ver9.87.0',
        'X-Tabelog-Appli-Unique-ID': options.deviceID,
        'X-Tabelog-Device-Size': '390.0 x 844.0',
        'X-Tabelog-Device-Scale': '3.0',
      },
    })
  }

  async getRestaurant(id: number): Promise<Restaurant> {
    const url = `/tabelog_appli/restaurant_detail/show?restaurant_id=${id}`
    const httpResponse = await this.request('GET', url)
    const apiResponse = restaurantDetailShowResponseSchema.parse(httpResponse.data)
    const rawRestaurant = apiResponse.restaurant

    return {
      address: rawRestaurant.address,
      averageBudget: rawRestaurant.average_budget,
      coordinate: new TokyoDatumCoordinate(
        rawRestaurant.location_information.latitude,
        rawRestaurant.location_information.longitude,
      ).worldGeodeticSystemCoordinate,
      genres: rawRestaurant.genre_name_list,
      id: rawRestaurant.id,
      name: rawRestaurant.name,
      reviewCount: rawRestaurant.total_review_count,
      score: rawRestaurant.total_score,
      webURL: new URL(rawRestaurant.tabelog_url),
    }
  }

  private request(method: Method, apiPath: string, params?: any): AxiosPromise {
    return this.axiosInstance.request({
      method: method,
      url: apiPath,
      params: params,
    })
  }
}

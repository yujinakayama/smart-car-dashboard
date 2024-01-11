const tabelogWebHosts = ['tabelog.com', 's.tabelog.com']

export function extractRestaurantIDFromURL(url: URL | string): number | null {
  if (typeof url == 'string') {
    url = new URL(url)
  }

  if (!tabelogWebHosts.includes(url.host)) {
    return null
  }

  // https://tabelog.com/tokyo/A1301/A130102/13168901/
  // https://tabelog.com/tokyo/A1301/A130102/13168901/dtlphotolst/smp2/
  // https://tabelog.com/en/tokyo/A1301/A130102/13168901/
  const result = url.pathname.match(/^(?:\/[a-z]{2})?\/[a-z]+\/[A-Z]\d+\/[A-Z]\d+\/(\d+)/)
  if (!result) {
    return null
  }

  return parseInt(result[1])
}
